import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerPropertyServicesScreen extends StatefulWidget {
  const ManagerPropertyServicesScreen({super.key});

  @override
  State<ManagerPropertyServicesScreen> createState() => _ManagerPropertyServicesScreenState();
}

class _ManagerPropertyServicesScreenState extends State<ManagerPropertyServicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Property Services',
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
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            'Property Service Management',
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
                        title: 'Power Washing / Sanitation',
                        description: 'Professional power washing and sanitation services',
                        color: Colors.blue,
                        onTap: () => _showMessage('Power washing service management coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.local_car_wash,
                        title: 'Dumpster Area Power Washing',
                        description: 'Focused power washing for dumpster areas',
                        color: Colors.cyan,
                        onTap: () => _showMessage('Dumpster area washing management coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.wash,
                        title: 'Pressure Washing Around Trash Areas',
                        description: 'High-pressure cleaning around trash zones',
                        color: Colors.teal,
                        onTap: () => _showMessage('Pressure washing management coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.delete_outline,
                        title: 'Compactor / Dumpster Zone Cleanup',
                        description: 'Maintenance and cleanup of trash compaction areas',
                        color: Colors.indigo,
                        onTap: () => _showMessage('Compactor zone management coming soon!'),
                      ),
                      const SizedBox(height: 12),
                      _buildServiceCard(
                        icon: Icons.cleaning_services,
                        title: 'Property Cleanup Requests',
                        description: 'Manage resident cleanup and maintenance requests',
                        color: Colors.purple,
                        onTap: () => _showMessage('Cleanup request management coming soon!'),
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
                Icons.settings,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
