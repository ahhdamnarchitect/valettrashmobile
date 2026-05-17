// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/skeleton_card.dart';

class PmComplianceReportScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;

  const PmComplianceReportScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<PmComplianceReportScreen> createState() =>
      _PmComplianceReportScreenState();
}

class _PmComplianceReportScreenState extends State<PmComplianceReportScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _runs = [];
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fromStr = DateTime(_from.year, _from.month, _from.day)
        .toUtc()
        .toIso8601String();
    final toStr = DateTime(_to.year, _to.month, _to.day, 23, 59, 59)
        .toUtc()
        .toIso8601String();
    final rows = await Supabase.instance.client
        .from('nightly_runs')
        .select('id, status, started_at, completed_at, created_at')
        .eq('property_id', widget.propertyId)
        .gte('created_at', fromStr)
        .lte('created_at', toStr)
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _runs = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    }
  }

  int get _completed =>
      _runs.where((r) => r['status'] == 'completed').length;

  String get _slaPercent {
    if (_runs.isEmpty) return '—';
    return '${(_completed / _runs.length * 100).toStringAsFixed(0)}%';
  }

  void _exportCsv() {
    final buf = StringBuffer();
    buf.writeln('Date,Status,Started,Completed');
    for (final r in _runs) {
      final date = _fmtDate(r['created_at'] as String? ?? '');
      final status = r['status'] ?? '';
      final started =
          r['started_at'] != null ? _fmtTs(r['started_at'] as String) : '';
      final completed =
          r['completed_at'] != null ? _fmtTs(r['completed_at'] as String) : '';
      buf.writeln('$date,$status,$started,$completed');
    }
    final content = buf.toString();
    final blob = html.Blob([content], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    (html.document.createElement('a') as html.AnchorElement)
      ..href = url
      ..download =
          '${widget.propertyName.replaceAll(' ', '_')}_compliance_${_fmtDate(DateTime.now().toIso8601String())}.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtTs(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Color _statusColor(String? status) => switch (status) {
        'completed' => AppColors.success,
        'in_progress' => AppColors.warning,
        'cancelled' => AppColors.error,
        _ => AppColors.textMuted,
      };

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
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loading && _runs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined,
                  color: AppColors.manager),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface1,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _dateChip('From', _from, (d) {
                  setState(() => _from = d);
                  _load();
                }),
                const SizedBox(width: 8),
                const Text('→', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(width: 8),
                _dateChip('To', _to, (d) {
                  setState(() => _to = d);
                  _load();
                }),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SLA $_slaPercent',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SkeletonCard(height: 56),
                      SizedBox(height: 8),
                      SkeletonCard(height: 56),
                      SizedBox(height: 8),
                      SkeletonCard(height: 56),
                    ],
                  )
                : _runs.isEmpty
                    ? const Center(
                        child: Text('No runs in this date range.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)))
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        itemCount: _runs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _runs[i];
                          final status = r['status'] as String?;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fmtDate(
                                            r['created_at'] as String? ?? ''),
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      if (r['started_at'] != null)
                                        Text(
                                          '${_fmtTs(r['started_at'] as String)} → ${r['completed_at'] != null ? _fmtTs(r['completed_at'] as String) : 'ongoing'}',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status ?? 'unknown',
                                    style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(
      String label, DateTime value, ValueChanged<DateTime> onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.manager,
                surface: AppColors.surface2,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '$label: ${_fmtDate(value.toIso8601String())}',
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}
