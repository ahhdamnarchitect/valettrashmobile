import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';

class SimpleNotificationSenderScreen extends StatefulWidget {
  final String? initialPropertyId;
  final String? initialMode;

  const SimpleNotificationSenderScreen({
    super.key,
    this.initialPropertyId,
    this.initialMode,
  });

  @override
  State<SimpleNotificationSenderScreen> createState() =>
      _SimpleNotificationSenderScreenState();
}

class _SimpleNotificationSenderScreenState
    extends State<SimpleNotificationSenderScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _userIdController = TextEditingController();

  late String _selectedType;
  late String _selectedMode;
  String? _selectedPropertyId;
  bool _isLoading = false;
  bool _propertiesLoading = true;
  List<Map<String, dynamic>> _properties = [];

  final _notificationTypes = [
    {'value': 'cancellation', 'label': 'Weather Cancellation'},
    {'value': 'holiday', 'label': 'Holiday Cancellation'},
    {'value': 'completed', 'label': 'Service Completed'},
    {'value': 'reminder', 'label': 'Bring Bins Back In'},
    {'value': 'alert', 'label': 'General Property Alert'},
  ];

  final _sendModes = [
    {'value': 'user', 'label': 'One Resident'},
    {'value': 'property', 'label': 'All at Property'},
    {'value': 'service_alert', 'label': 'Service Alert (All)'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = 'cancellation';
    _selectedMode = widget.initialMode ?? 'property';
    _selectedPropertyId = widget.initialPropertyId;
    _loadProperties();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    try {
      final rows = await Supabase.instance.client
          .from('properties')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      setState(() {
        _properties = List<Map<String, dynamic>>.from(rows as List);
        if (_selectedPropertyId == null && _properties.isNotEmpty) {
          _selectedPropertyId = _properties.first['id']?.toString();
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _propertiesLoading = false);
    }
  }

  String _toDbNotificationType(String ui) {
    switch (ui) {
      case 'cancellation':
      case 'holiday':
        return 'pickup_reminder';
      case 'completed':
      case 'reminder':
        return 'team_arrived';
      case 'alert':
        return 'violation_reported';
      default:
        return 'billing_alert';
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and message')),
      );
      return;
    }
    if (_selectedMode == 'user' && _userIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a resident user ID')),
      );
      return;
    }
    if ((_selectedMode == 'property' || _selectedMode == 'service_alert') &&
        _selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final uiTemplate =
          _selectedMode == 'service_alert' ? 'completed' : _selectedType;

      final notificationData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _toDbNotificationType(uiTemplate),
        'sender_id': currentUser.id,
        'is_active': true,
        'data': {'ui_type': _selectedType, 'mode': _selectedMode},
      };

      switch (_selectedMode) {
        case 'user':
          notificationData['user_id'] = _userIdController.text.trim();
          break;
        case 'property':
        case 'service_alert':
          notificationData['property_id'] = _selectedPropertyId;
          break;
      }

      await supabase.from('notifications').insert(notificationData);

      _titleController.clear();
      _messageController.clear();
      _userIdController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification sent'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          'Send Notification',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.manager.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: AppColors.manager,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Notification',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Notify one resident or the whole property',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Form card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('DELIVERY'),
                  const SizedBox(height: 12),

                  // Send Mode chips
                  Wrap(
                    spacing: 8,
                    children: _sendModes.map((mode) {
                      final selected = _selectedMode == mode['value'];
                      return ChoiceChip(
                        label: Text(mode['label']!),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedMode = mode['value']!),
                        selectedColor: AppColors.manager.withValues(alpha: 0.2),
                        backgroundColor: AppColors.surface2,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.manager
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.manager.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Property dropdown
                  if (_selectedMode == 'property' ||
                      _selectedMode == 'service_alert') ...[
                    _propertiesLoading
                        ? const LinearProgressIndicator(
                            color: AppColors.manager,
                            backgroundColor: AppColors.surface2,
                          )
                        : _darkDropdown<String>(
                            value: _selectedPropertyId,
                            label: 'Property',
                            icon: Icons.apartment_outlined,
                            items: _properties
                                .map((p) => DropdownMenuItem(
                                      value: p['id']?.toString(),
                                      child: Text(p['name']?.toString() ?? ''),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedPropertyId = v),
                          ),
                    const SizedBox(height: 16),
                  ],

                  // User ID field
                  if (_selectedMode == 'user') ...[
                    _darkTextField(
                      controller: _userIdController,
                      label: 'Resident User ID',
                      icon: Icons.person_outline,
                      hint: 'Paste resident UUID...',
                    ),
                    const SizedBox(height: 16),
                  ],

                  _sectionLabel('MESSAGE'),
                  const SizedBox(height: 12),

                  // Notification Type
                  _darkDropdown<String>(
                    value: _selectedType,
                    label: 'Type',
                    icon: Icons.label_outline,
                    items: _notificationTypes
                        .map((t) => DropdownMenuItem(
                              value: t['value'],
                              child: Text(t['label']!),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                  const SizedBox(height: 12),

                  _darkTextField(
                    controller: _titleController,
                    label: 'Title',
                    icon: Icons.title,
                    hint: 'Notification title...',
                  ),
                  const SizedBox(height: 12),

                  _darkTextField(
                    controller: _messageController,
                    label: 'Message',
                    icon: Icons.message_outlined,
                    hint: 'Message body...',
                    maxLines: 4,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            PrimaryButton(
              label: _isLoading ? 'Sending...' : 'Send Notification',
              accent: AppColors.manager,
              onPressed: _isLoading ? null : _sendNotification,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );

  Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.manager, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _darkDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: AppColors.surface2,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      icon: const Icon(Icons.keyboard_arrow_down,
          color: AppColors.textMuted, size: 18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.manager, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
