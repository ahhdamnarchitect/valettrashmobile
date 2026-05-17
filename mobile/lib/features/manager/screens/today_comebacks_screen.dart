import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/widgets/stat_tile.dart';

class TodayComebacksScreen extends StatefulWidget {
  const TodayComebacksScreen({super.key});

  @override
  State<TodayComebacksScreen> createState() => _TodayComebacksScreenState();
}

class _TodayComebacksScreenState extends State<TodayComebacksScreen> {
  List<Map<String, dynamic>> _comebacks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      final rows = await supabase
          .from('missed_pickup_requests')
          .select(
              'id, status, requested_at, completed_at, is_free, fee_amount, resident_user_id, pickup_id, pickups(unit_id, units(unit_number), nightly_run_id, nightly_runs(properties(name)))')
          .gte('created_at', todayStart)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _comebacks = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'expired':
        return 'Expired';
      default:
        return 'Pending';
    }
  }

  String? _unitNumber(Map<String, dynamic> row) {
    final pickup = row['pickups'];
    if (pickup is! Map) return null;
    final units = pickup['units'];
    if (units is! Map) return null;
    return units['unit_number']?.toString();
  }

  String? _propertyName(Map<String, dynamic> row) {
    final pickup = row['pickups'];
    if (pickup is! Map) return null;
    final run = pickup['nightly_runs'];
    if (run is! Map) return null;
    final prop = run['properties'];
    if (prop is! Map) return null;
    return prop['name']?.toString();
  }

  String _formatTime(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h12:$min $ap';
    } catch (_) {
      return isoStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _comebacks.where((c) => c['status'] == 'pending').length;
    final inProgress =
        _comebacks.where((c) => c['status'] == 'accepted').length;
    final completed =
        _comebacks.where((c) => c['status'] == 'completed').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Today's Comebacks",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? _buildSkeleton()
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildStatsBar(pending, inProgress, completed),
                    Expanded(
                      child: _comebacks.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppColors.manager,
                              backgroundColor: AppColors.surface2,
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 32),
                                itemCount: _comebacks.length,
                                itemBuilder: (context, index) =>
                                    _comebackCard(_comebacks[index]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonCard(height: 80),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadData,
              icon:
                  const Icon(Icons.refresh, color: AppColors.manager, size: 18),
              label: const Text('Retry',
                  style: TextStyle(color: AppColors.manager)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'No comebacks today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All pickups completed successfully',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int pending, int inProgress, int completed) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Pending',
              value: '$pending',
              valueColor: AppColors.warning,
            ),
          ),
          Container(
              width: 1, height: 36, color: AppColors.border),
          Expanded(
            child: StatTile(
              label: 'In Progress',
              value: '$inProgress',
              valueColor: AppColors.info,
            ),
          ),
          Container(
              width: 1, height: 36, color: AppColors.border),
          Expanded(
            child: StatTile(
              label: 'Done',
              value: '$completed',
              valueColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comebackCard(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? 'pending';
    final color = _statusColor(status);
    final label = _statusLabel(status);
    final unit = _unitNumber(row);
    final property = _propertyName(row);
    final isFree = row['is_free'] as bool? ?? true;
    final requestedAt = row['requested_at'] as String?;
    final completedAt = row['completed_at'] as String?;
    final id = row['id'] as String? ?? '';

    final locationLabel = property != null && unit != null
        ? '$property – Unit $unit'
        : unit != null
            ? 'Unit $unit'
            : 'Request ${id.length > 8 ? id.substring(0, 8) : id}…';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    locationLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GlowBadge(label: label, accent: color, showDot: false),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  isFree ? Icons.check_circle_outline : Icons.attach_money,
                  size: 14,
                  color: isFree ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 5),
                Text(
                  isFree ? 'Free pickup' : 'Paid pickup',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                if (requestedAt != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(requestedAt),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
            if (completedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 5),
                  Text(
                    'Completed ${_formatTime(completedAt)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
