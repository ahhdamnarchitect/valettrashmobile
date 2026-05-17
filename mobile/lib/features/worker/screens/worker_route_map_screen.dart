import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/skeleton_card.dart';

class WorkerRouteMapScreen extends StatefulWidget {
  final String propertyName;
  final List<Map<String, dynamic>> comebacks;

  const WorkerRouteMapScreen({
    super.key,
    required this.propertyName,
    this.comebacks = const [],
  });

  @override
  State<WorkerRouteMapScreen> createState() => _WorkerRouteMapScreenState();
}

class _WorkerRouteMapScreenState extends State<WorkerRouteMapScreen> {
  final MapController _mapController = MapController();
  bool _loading = true;

  // Default: center of US — overridden if property has lat/lng in DB
  LatLng _center = const LatLng(37.09, -95.71);
  double _zoom = 15.0;
  bool _hasCoordinates = false;

  List<Map<String, dynamic>> _routeStops = [];
  int _completedStops = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // Try to get property coordinates (lat/lng columns may or may not exist)
      try {
        final assigns = await client
            .from('worker_assignments')
            .select('property_id, properties(name, latitude, longitude)')
            .eq('user_id', user.id)
            .eq('is_active', true);

        for (final row in List<Map<String, dynamic>>.from(assigns as List)) {
          final p = row['properties'];
          if (p is Map) {
            final lat = p['latitude'];
            final lng = p['longitude'];
            if (lat != null && lng != null) {
              _center = LatLng(
                (lat as num).toDouble(),
                (lng as num).toDouble(),
              );
              _hasCoordinates = true;
              break;
            }
          }
        }
      } catch (_) {
        // latitude/longitude columns may not exist yet — that's OK
      }

      // Load route stops
      final routes = await client
          .from('routes')
          .select('id, name')
          .eq('worker_id', user.id)
          .eq('is_active', true);

      final routeList = List<Map<String, dynamic>>.from(routes as List);
      if (routeList.isNotEmpty) {
        final routeId = routeList.first['id'];
        final stops = await client
            .from('route_stops')
            .select('stop_order, completed, units(unit_number)')
            .eq('route_id', routeId)
            .order('stop_order', ascending: true);
        _routeStops = List<Map<String, dynamic>>.from(stops as List);
        _completedStops =
            _routeStops.where((s) => s['completed'] == true).length;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.propertyName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loading && _routeStops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GlowBadge(
                label: '$_completedStops/${_routeStops.length}',
                accent: AppColors.worker,
                showDot: _completedStops < _routeStops.length,
              ),
            ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                SkeletonCard(height: 300),
                SizedBox(height: 12),
                SkeletonCard(height: 60),
                SizedBox(height: 8),
                SkeletonCard(height: 60),
              ],
            )
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: _zoom,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.valettrash.mobile',
                          ),
                          if (_hasCoordinates)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _center,
                                  width: 80,
                                  height: 56,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.worker,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.worker
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          widget.propertyName
                                              .split(' ')
                                              .first,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.location_on,
                                        color: AppColors.worker,
                                        size: 22,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Comeback markers
                                ...widget.comebacks
                                    .take(5)
                                    .map((cb) => Marker(
                                          point: LatLng(
                                            _center.latitude +
                                                0.0002 *
                                                    (widget.comebacks
                                                            .indexOf(cb) +
                                                        1),
                                            _center.longitude +
                                                0.0002 *
                                                    (widget.comebacks
                                                            .indexOf(cb) +
                                                        1),
                                          ),
                                          width: 36,
                                          height: 36,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.warning,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.warning
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.replay,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        )),
                              ],
                            ),
                        ],
                      ),
                      // No coordinates message
                      if (!_hasCoordinates)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface1.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.warning, size: 16),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Property coordinates not set — ask your manager to add the address.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Map zoom controls
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Column(
                          children: [
                            _mapButton(Icons.add, () {
                              _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1);
                            }),
                            const SizedBox(height: 6),
                            _mapButton(Icons.remove, () {
                              _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1);
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Route stops list
                Expanded(
                  flex: 2,
                  child: _buildStopsList(),
                ),
              ],
            ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
    );
  }

  Widget _buildStopsList() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Tonight\'s Stops',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                if (widget.comebacks.isNotEmpty)
                  GlowBadge(
                    label: '${widget.comebacks.length} comeback${widget.comebacks.length == 1 ? '' : 's'}',
                    accent: AppColors.warning,
                    showDot: true,
                  ),
              ],
            ),
          ),
          if (_routeStops.isEmpty && widget.comebacks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'No stops assigned for tonight.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (_routeStops.isNotEmpty)
                    ..._routeStops.asMap().entries.map((entry) {
                      final i = entry.key;
                      final stop = entry.value;
                      final u = stop['units'];
                      final unitNum =
                          u is Map ? u['unit_number']?.toString() ?? '?' : '?';
                      final done = stop['completed'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: done
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.worker.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: done
                                    ? const Icon(Icons.check,
                                        size: 14,
                                        color: AppColors.success)
                                    : Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.worker,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Unit $unitNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: done
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (done)
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppColors.success),
                          ],
                        ),
                      );
                    }),
                  if (widget.comebacks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'COMEBACKS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.comebacks.map((cb) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.replay,
                                  size: 14,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Unit ${cb['unit'] ?? '?'} — Comeback',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
