import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerAlertsScreen extends StatefulWidget {
  const ManagerAlertsScreen({super.key});

  @override
  State<ManagerAlertsScreen> createState() => _ManagerAlertsScreenState();
}

class _ManagerAlertsScreenState extends State<ManagerAlertsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _targetUserController = TextEditingController();
  String _selectedType = 'cancellation';
  String _selectedTargeting = 'global';
  bool _isLoading = false;

  final _alertTypes = [
    {'value': 'cancellation', 'label': 'Weather Cancellation'},
    {'value': 'holiday', 'label': 'Holiday Cancellation'},
    {'value': 'completed', 'label': 'Service Completed'},
    {'value': 'reminder', 'label': 'Bring Bins Back In'},
    {'value': 'alert', 'label': 'General Property Alert'},
  ];

  final _targetingOptions = [
    {'value': 'user', 'label': 'Specific Resident'},
    {'value': 'property', 'label': 'All Residents at Property'},
    {'value': 'global', 'label': 'All Residents (Global)'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetUserController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and message')),
      );
      return;
    }

    if (_selectedTargeting == 'user' && _targetUserController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a user ID or email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        Map<String, dynamic> notificationData = {
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
          'type': _selectedType,
          'audience': 'resident',
          'sender_id': currentUser.id,
          'is_active': true,
        };

        // Set targeting based on selection
        switch (_selectedTargeting) {
          case 'user':
            notificationData['user_id'] = _targetUserController.text.trim();
            break;
          case 'property':
            // For now, use current user's property (in real app, would have property selector)
            final userProperties = await supabase
                .from('user_properties')
                .select('property_id')
                .eq('user_id', currentUser.id)
                .limit(1);
            if (userProperties.isNotEmpty) {
              notificationData['property_id'] = userProperties[0]['property_id'];
            }
            break;
          case 'global':
            // Global notification - no user_id or property_id
            break;
        }

        await supabase.from('notifications').insert(notificationData);

        _titleController.clear();
        _messageController.clear();
        _targetUserController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert sent successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send alert: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Service Alerts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Send Service Alert',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create and send alerts to residents about service updates, cancellations, and important information.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Alert Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alert Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Alert Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Alert Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _alertTypes.map((type) {
                          return DropdownMenuItem(
                            value: type['value'],
                            child: Text(type['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedType = value!);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Alert Title',
                          border: OutlineInputBorder(),
                          hintText: 'Enter alert title...',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Message
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Alert Message',
                          border: OutlineInputBorder(),
                          hintText: 'Enter detailed message...',
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Targeting Options
                      DropdownButtonFormField<String>(
                        value: _selectedTargeting,
                        decoration: const InputDecoration(
                          labelText: 'Targeting',
                          border: OutlineInputBorder(),
                        ),
                        items: _targetingOptions.map((option) {
                          return DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedTargeting = value!);
                        },
                      ),
                      if (_selectedTargeting == 'user') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _targetUserController,
                          decoration: const InputDecoration(
                            labelText: 'User ID or Email',
                            border: OutlineInputBorder(),
                            hintText: 'Enter resident user ID or email...',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Send Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _sendAlert,
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_isLoading ? 'Sending...' : 'Send Alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
