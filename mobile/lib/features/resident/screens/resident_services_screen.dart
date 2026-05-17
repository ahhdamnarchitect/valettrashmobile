import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentServicesScreen extends StatefulWidget {
  const ResidentServicesScreen({super.key});

  @override
  State<ResidentServicesScreen> createState() => _ResidentServicesScreenState();
}

class _ResidentServicesScreenState extends State<ResidentServicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Services',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resident Add-on Services
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
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Resident Add-on Services',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildServiceCard(
                        icon: Icons.loop,
                        title: 'Comeback Pickup',
                        description: 'Request an additional pickup service',
                        color: Colors.orange,
                        onTap: () => _showMessage('Comeback pickup service coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.inventory_2,
                        title: 'Bulk Pickup',
                        description: 'Schedule pickup for large items or bulk trash',
                        color: Colors.green,
                        onTap: () => _showMessage('Bulk pickup service coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.cleaning_services,
                        title: 'Carpet Cleaning',
                        description: 'Professional carpet cleaning service',
                        color: Colors.purple,
                        onTap: () => _showMessage('Carpet cleaning service coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.cleaning_services,
                        title: 'Maid / Cleaning Service',
                        description: 'Professional home cleaning services',
                        color: Colors.teal,
                        onTap: () => _showMessage('Maid service coming soon!'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Property-level Services
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
                              Icons.location_city,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Property-level Services',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildServiceCard(
                        icon: Icons.water_drop,
                        title: 'Dumpster Area Power Washing',
                        description: 'Professional power washing for dumpster areas',
                        color: Colors.blue,
                        onTap: () => _showMessage('Power washing service coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.local_car_wash,
                        title: 'Pressure Washing Around Trash Areas',
                        description: 'High-pressure cleaning around trash zones',
                        color: Colors.cyan,
                        onTap: () => _showMessage('Pressure washing service coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Cleanup Around Dumpster/Compactor Zones',
                        description: 'General cleanup and maintenance of trash areas',
                        color: Colors.indigo,
                        onTap: () => _showMessage('Cleanup service coming soon!'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Support & Concerns Section
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
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.support_agent,
                              color: Colors.amber.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Support & Concerns',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'How can we help you today?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildConcernChip('Missed Pickup'),
                          _buildConcernChip('Billing Issue'),
                          _buildConcernChip('Service Concern'),
                          _buildConcernChip('Cleanliness Concern'),
                          _buildConcernChip('Add-on Service Question'),
                          _buildConcernChip('General Feedback'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showSupportDialog,
                          icon: const Icon(Icons.message),
                          label: const Text('Send Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
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

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String description,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConcernChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Support Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a category for your message:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'missed_pickup', child: Text('Missed Pickup')),
                DropdownMenuItem(value: 'billing_issue', child: Text('Billing Issue')),
                DropdownMenuItem(value: 'service_concern', child: Text('Service Concern')),
                DropdownMenuItem(value: 'cleanliness_concern', child: Text('Cleanliness Concern')),
                DropdownMenuItem(value: 'addon_service_question', child: Text('Add-on Service Question')),
                DropdownMenuItem(value: 'general_feedback', child: Text('General Feedback')),
              ],
              onChanged: (value) {
                // Handle category selection
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                hintText: 'Describe your concern or question...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement photo upload
                      _showMessage('Photo upload coming soon!');
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Add Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMessage('Support message sent successfully!');
                    },
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
