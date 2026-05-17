import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';

class ResidentViolationsScreen extends StatefulWidget {
  const ResidentViolationsScreen({super.key});

  @override
  State<ResidentViolationsScreen> createState() => _ResidentViolationsScreenState();
}

class _ResidentViolationsScreenState extends State<ResidentViolationsScreen> {
  List<Map<String, dynamic>> _violations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  Future<void> _loadViolations() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final violations = await supabase
            .from('violations')
            .select('*')
            .eq('resident_user_id', currentUser.id)
            .order('created_at', ascending: false);
        setState(() {
          _violations = List<Map<String, dynamic>>.from(violations);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _violations = [];
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }

  String _getViolationTypeDisplay(String? type) {
    switch (type?.toLowerCase()) {
      case 'missed_pickup':
        return 'Missed Pickup';
      case 'contamination':
        return 'Contamination';
      case 'overweight':
        return 'Overweight';
      case 'improper_disposal':
        return 'Improper Disposal';
      default:
        return type ?? 'Violation';
    }
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
        title: const Text(
          'My Violations',
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
            onPressed: () {
              setState(() => _isLoading = true);
              _loadViolations();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.resident),
            )
          : _violations.isEmpty
              ? _buildEmptyState()
              : _buildViolationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Violations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Great job! You have no violations on record.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _violations.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${_violations.length} Violation${_violations.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        return _buildViolationCard(_violations[index - 1]);
      },
    );
  }

  Widget _buildViolationCard(Map<String, dynamic> violation) {
    final type = _getViolationTypeDisplay(violation['violation_type']);
    final description = violation['description'] ?? 'No description available';
    final date = _formatDate(violation['created_at']);
    final isCharged = violation['is_warning'] == false;
    final photoUrl = violation['photo_url'];
    final accentColor = isCharged ? AppColors.error : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCharged ? Icons.attach_money : Icons.warning_amber,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GlowBadge(
                  label: isCharged ? 'Charged' : 'Warning',
                  accent: accentColor,
                  showDot: false,
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1, color: AppColors.border),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (photoUrl != null && (photoUrl as String).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photoUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textMuted,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
