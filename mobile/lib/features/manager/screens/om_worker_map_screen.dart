import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';

class OmWorkerMapScreen extends StatefulWidget {
  const OmWorkerMapScreen({super.key});

  @override
  State<OmWorkerMapScreen> createState() => _OmWorkerMapScreenState();
}

class _OmWorkerMapScreenState extends State<OmWorkerMapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  static const _center = LatLng(37.09, -95.71);

  @override
  void initState() {
    super.initState();
    Supabase.instance.client
        .from('worker_locations')
        .stream(primaryKey: ['user_id'])
        .map((rows) => List<Map<String, dynamic>>.from(rows))
        .listen((rows) {
          if (mounted) {
            setState(() {
              _locations = rows;
              _loading = false;
            });
          }
        });
  }

  LatLng _mapCenter() {
    if (_locations.isEmpty) return _center;
    final lats =
        _locations.map((l) => (l['latitude'] as num).toDouble()).toList();
    final lngs =
        _locations.map((l) => (l['longitude'] as num).toDouble()).toList();
    return LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lngs.reduce((a, b) => a + b) / lngs.length,
    );
  }

  String _ago(String? iso) {
    if (iso == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
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
        title: const Text('Live Worker Map',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GlowBadge(
              label: '${_locations.length} online',
              accent: AppColors.worker,
              showDot: _locations.isNotEmpty,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter(),
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.valettrash.mobile',
                      ),
                      MarkerLayer(
                        markers: _locations.map((loc) {
                          final lat = (loc['latitude'] as num).toDouble();
                          final lng = (loc['longitude'] as num).toDouble();
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.worker,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.worker
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 20),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface1,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: _locations.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_off_outlined,
                                    color: AppColors.textMuted, size: 32),
                                SizedBox(height: 8),
                                Text('No workers sharing location',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14)),
                                SizedBox(height: 4),
                                Text(
                                    'Workers share their location from the Route tab.',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: _locations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final loc = _locations[i];
                              return Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.worker
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person,
                                        color: AppColors.worker, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Worker ${(loc['user_id'] as String).substring(0, 8)}…',
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    _ago(loc['updated_at'] as String?),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
