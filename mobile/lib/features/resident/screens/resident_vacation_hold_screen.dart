import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class ResidentVacationHoldScreen extends StatefulWidget {
  const ResidentVacationHoldScreen({super.key});

  @override
  State<ResidentVacationHoldScreen> createState() =>
      _ResidentVacationHoldScreenState();
}

class _ResidentVacationHoldScreenState
    extends State<ResidentVacationHoldScreen> {
  bool _loading = true;
  bool _isOnHold = false;
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await Supabase.instance.client
        .from('resident_units')
        .select('is_on_hold, hold_note')
        .eq('user_id', uid)
        .eq('is_active', true)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _isOnHold = row?['is_on_hold'] == true;
        _noteController.text = row?['hold_note'] as String? ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client
          .from('resident_units')
          .update({
            'is_on_hold': _isOnHold,
            'hold_note': _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          })
          .eq('user_id', uid)
          .eq('is_active', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isOnHold
              ? 'Vacation hold activated. Pickups paused.'
              : 'Vacation hold removed. Pickups resumed.'),
          backgroundColor:
              _isOnHold ? AppColors.warning : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Vacation Hold',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.warning, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'While on hold your bags will not be collected. Turn off hold before your scheduled pickup night.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pause my pickups',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Going on vacation or extended travel',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isOnHold,
                      onChanged: (v) => setState(() => _isOnHold = v),
                      activeColor: AppColors.resident,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Note (optional)',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. "Away May 20–27"',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface1,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.resident, width: 1.5)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.resident,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }
}
