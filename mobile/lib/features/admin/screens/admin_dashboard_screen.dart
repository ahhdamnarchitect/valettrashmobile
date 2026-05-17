import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/screens/change_password_screen.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/role_theme.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/skeleton_card.dart';
import 'admin_invite_codes_screen.dart';

// ── Roles available for assignment ────────────────────────────────────────────
const _kRoles = [
  'resident',
  'driver',
  'property_manager',
  'operations_manager',
  'super_admin',
];

const _kRoleLabels = {
  'resident': 'Resident',
  'driver': 'Worker/Driver',
  'property_manager': 'Property Manager',
  'operations_manager': 'Operations Manager',
  'super_admin': 'Super Admin',
};

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tabIndex = 0;
  AppColorsScheme? _c;

  // Users tab
  List<Map<String, dynamic>> _users = [];
  bool _usersLoading = true;
  String _userSearch = '';

  // Properties tab
  List<Map<String, dynamic>> _properties = [];
  bool _propsLoading = true;

  // Residents tab
  List<Map<String, dynamic>> _residents = [];
  bool _residentsLoading = true;
  String? _residentPropFilter;

  // Concerns tab
  List<Map<String, dynamic>> _concerns = [];
  bool _concernsLoading = true;
  String _concernFilter = 'open';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c = context.roleColors;
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadProperties();
    _loadResidents();
    _loadConcerns();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadUsers() async {
    setState(() => _usersLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('id, first_name, last_name, email, role, created_at')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(rows as List);
          _usersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _loadProperties() async {
    setState(() => _propsLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('properties')
          .select(
              'id, name, service_window_start, service_window_end, free_comeback_pickups_per_month, comeback_pickup_fee, is_active')
          .order('name');
      if (mounted) {
        setState(() {
          _properties = List<Map<String, dynamic>>.from(rows as List);
          _propsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _propsLoading = false);
    }
  }

  Future<void> _loadResidents() async {
    setState(() => _residentsLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('resident_units')
          .select(
              'id, user_id, unit_id, property_id, is_active, is_on_hold, hold_note, move_in_date, users(first_name, last_name, email), units(unit_number), properties(name)')
          .eq('is_active', true)
          .order('move_in_date', ascending: false);
      if (mounted) {
        setState(() {
          _residents = List<Map<String, dynamic>>.from(rows as List);
          _residentsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _residentsLoading = false);
    }
  }

  Future<void> _loadConcerns() async {
    setState(() => _concernsLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('resident_concerns')
          .select(
              'id, subject, message, status, created_at, resident_user_id, property_id, users(first_name, last_name), properties(name)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _concerns = List<Map<String, dynamic>>.from(rows as List);
          _concernsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _concernsLoading = false);
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  Future<void> _updateUser(String id, Map<String, dynamic> updates) async {
    try {
      await Supabase.instance.client.from('users').update(updates).eq('id', id);
      _loadUsers();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> _updateProperty(String id, Map<String, dynamic> updates) async {
    try {
      await Supabase.instance.client
          .from('properties')
          .update(updates)
          .eq('id', id);
      _loadProperties();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> _updateResidentUnit(
      String id, Map<String, dynamic> updates) async {
    try {
      await Supabase.instance.client
          .from('resident_units')
          .update(updates)
          .eq('id', id);
      _loadResidents();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  Future<void> _deactivateResident(String id) async {
    try {
      await Supabase.instance.client
          .from('resident_units')
          .update({'is_active': false}).eq('id', id);
      _loadResidents();
      _snack('Resident deactivated');
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Future<void> _updateConcernStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('resident_concerns')
          .update({'status': status}).eq('id', id);
      _loadConcerns();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Shell ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _c ?? AppColorsScheme.light;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildTab(c)),
            RoleBottomNav(
              currentIndex: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              accent: const Color(0xFF6366F1),
              items: const [
                RoleNavItem(
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: 'Users'),
                RoleNavItem(
                    icon: Icons.apartment_outlined,
                    activeIcon: Icons.apartment,
                    label: 'Properties'),
                RoleNavItem(
                    icon: Icons.home_work_outlined,
                    activeIcon: Icons.home_work,
                    label: 'Residents'),
                RoleNavItem(
                    icon: Icons.inbox_outlined,
                    activeIcon: Icons.inbox,
                    label: 'Concerns'),
                RoleNavItem(
                    icon: Icons.build_outlined,
                    activeIcon: Icons.build,
                    label: 'Tools'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(AppColorsScheme c) {
    switch (_tabIndex) {
      case 0:
        return _buildUsersTab(c);
      case 1:
        return _buildPropertiesTab(c);
      case 2:
        return _buildResidentsTab(c);
      case 3:
        return _buildConcernsTab(c);
      default:
        return _buildToolsTab(c);
    }
  }

  // ── Users Tab ────────────────────────────────────────────────────────────────

  Widget _buildUsersTab(AppColorsScheme c) {
    final filtered = _users.where((u) {
      if (_userSearch.isEmpty) return true;
      final q = _userSearch.toLowerCase();
      final name =
          '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(c, 'Users', '${_users.length} accounts'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _userSearch = v),
            style: TextStyle(color: c.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: c.textMuted, size: 18),
              filled: true,
              fillColor: c.surface1,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: _usersLoading
              ? _skeletons()
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _userCard(c, filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _userCard(AppColorsScheme c, Map<String, dynamic> u) {
    final name =
        '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    final role = u['role']?.toString() ?? 'resident';
    final roleLabel = _kRoleLabels[role] ?? role;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return InkWell(
      onTap: () => _showUserEditSheet(u),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
              child: Text(initial,
                  style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Unnamed' : name,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(u['email']?.toString() ?? '',
                      style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            _rolePill(roleLabel),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showUserEditSheet(Map<String, dynamic> u) {
    final fnCtrl =
        TextEditingController(text: u['first_name']?.toString() ?? '');
    final lnCtrl =
        TextEditingController(text: u['last_name']?.toString() ?? '');
    String role = u['role']?.toString() ?? 'resident';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _editSheet(
          title: 'Edit User',
          subtitle: u['email']?.toString() ?? '',
          children: [
            _sheetField(fnCtrl, 'First Name'),
            const SizedBox(height: 12),
            _sheetField(lnCtrl, 'Last Name'),
            const SizedBox(height: 12),
            _sheetLabel('EMAIL'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(u['email']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
            const SizedBox(height: 12),
            _sheetLabel('ROLE'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: role,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              items: _kRoles
                  .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(_kRoleLabels[r] ?? r,
                          style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setSheet(() => role = v);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateUser(u['id'].toString(), {
                  'first_name': fnCtrl.text.trim(),
                  'last_name': lnCtrl.text.trim(),
                  'role': role,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Properties Tab ───────────────────────────────────────────────────────────

  Widget _buildPropertiesTab(AppColorsScheme c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(c, 'Properties', '${_properties.length} properties'),
        Expanded(
          child: _propsLoading
              ? _skeletons()
              : RefreshIndicator(
                  onRefresh: _loadProperties,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _properties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _propertyCard(c, _properties[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _propertyCard(AppColorsScheme c, Map<String, dynamic> p) {
    final start = _fmtTime(p['service_window_start']);
    final end = _fmtTime(p['service_window_end']);
    final freeCb =
        p['free_comeback_pickups_per_month']?.toString() ?? '—';
    final fee = p['comeback_pickup_fee'] != null
        ? '\$${double.tryParse(p['comeback_pickup_fee'].toString())?.toStringAsFixed(2) ?? '—'}'
        : '—';
    final active = p['is_active'] == true;

    return InkWell(
      onTap: () => _showPropertyEditSheet(p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(p['name']?.toString() ?? '',
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(width: 8),
                    if (!active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Inactive',
                            style: TextStyle(
                                color: AppColors.error, fontSize: 10)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text('$start – $end  ·  $freeCb free comeback/mo  ·  $fee fee',
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showPropertyEditSheet(Map<String, dynamic> p) {
    final nameCtrl =
        TextEditingController(text: p['name']?.toString() ?? '');
    final startCtrl = TextEditingController(
        text: p['service_window_start']?.toString() ?? '18:00:00');
    final endCtrl = TextEditingController(
        text: p['service_window_end']?.toString() ?? '22:00:00');
    final freeCtrl = TextEditingController(
        text: p['free_comeback_pickups_per_month']?.toString() ?? '1');
    final feeCtrl = TextEditingController(
        text: p['comeback_pickup_fee']?.toString() ?? '15.00');
    bool active = p['is_active'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _editSheet(
          title: 'Edit Property',
          subtitle: p['name']?.toString() ?? '',
          children: [
            _sheetField(nameCtrl, 'Property Name'),
            const SizedBox(height: 12),
            _sheetLabel('SERVICE WINDOW (24h format, e.g. 18:00:00)'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _sheetField(startCtrl, 'Start')),
              const SizedBox(width: 12),
              Expanded(child: _sheetField(endCtrl, 'End')),
            ]),
            const SizedBox(height: 12),
            _sheetLabel('COMEBACKS'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: _sheetField(freeCtrl, 'Free/month',
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _sheetField(feeCtrl, 'Fee (\$)',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Text('Active',
                  style:
                      TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              const Spacer(),
              Switch(
                value: active,
                onChanged: (v) => setSheet(() => active = v),
                activeColor: const Color(0xFF6366F1),
              ),
            ]),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateProperty(p['id'].toString(), {
                  'name': nameCtrl.text.trim(),
                  'service_window_start': startCtrl.text.trim(),
                  'service_window_end': endCtrl.text.trim(),
                  'free_comeback_pickups_per_month':
                      int.tryParse(freeCtrl.text.trim()) ?? 1,
                  'comeback_pickup_fee':
                      double.tryParse(feeCtrl.text.trim()) ?? 15.0,
                  'is_active': active,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Residents Tab ────────────────────────────────────────────────────────────

  Widget _buildResidentsTab(AppColorsScheme c) {
    final propNames = {
      for (final p in _properties) p['id']?.toString(): p['name']?.toString()
    };
    final filtered = _residentPropFilter == null
        ? _residents
        : _residents
            .where((r) =>
                r['property_id']?.toString() == _residentPropFilter)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(c, 'Residents', '${filtered.length} active assignments'),
        // Property filter chips
        if (_properties.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip(c, 'All', _residentPropFilter == null,
                    () => setState(() => _residentPropFilter = null)),
                ...(_properties.map((p) => _filterChip(
                    c,
                    p['name']?.toString() ?? '',
                    _residentPropFilter == p['id']?.toString(),
                    () => setState(() =>
                        _residentPropFilter = p['id']?.toString())))),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _residentsLoading
              ? _skeletons()
              : RefreshIndicator(
                  onRefresh: _loadResidents,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _residentCard(c, filtered[i], propNames),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _residentCard(AppColorsScheme c, Map<String, dynamic> r,
      Map<String?, String?> propNames) {
    final user = r['users'];
    final name = user is Map
        ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
        : 'Unknown';
    final unit = (r['units'] is Map)
        ? r['units']['unit_number']?.toString() ?? '?'
        : '?';
    final prop = (r['properties'] is Map)
        ? r['properties']['name']?.toString() ?? '?'
        : '?';
    final onHold = r['is_on_hold'] == true;

    return InkWell(
      onTap: () => _showResidentEditSheet(r),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Unknown' : name,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('$prop — Unit $unit',
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (onHold)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('On Hold',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showResidentEditSheet(Map<String, dynamic> r) {
    final user = r['users'];
    final name = user is Map
        ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
        : 'Resident';
    final noteCtrl = TextEditingController(
        text: r['hold_note']?.toString() ?? '');
    bool onHold = r['is_on_hold'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _editSheet(
          title: 'Edit Resident',
          subtitle: name,
          children: [
            Row(children: [
              Text('Vacation Hold',
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              const Spacer(),
              Switch(
                value: onHold,
                onChanged: (v) => setSheet(() => onHold = v),
                activeColor: AppColors.warning,
              ),
            ]),
            if (onHold) ...[
              const SizedBox(height: 8),
              _sheetField(noteCtrl, 'Hold Note (optional)',
                  hint: 'e.g. Away for 2 weeks'),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateResidentUnit(r['id'].toString(), {
                  'is_on_hold': onHold,
                  'hold_note': onHold ? noteCtrl.text.trim() : null,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Deactivate Resident?'),
                    content: Text(
                        'This will remove $name from their unit assignment. This cannot be undone easily.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dCtx);
                          _deactivateResident(r['id'].toString());
                        },
                        child: const Text('Deactivate',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Deactivate Resident'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Concerns Tab ─────────────────────────────────────────────────────────────

  Widget _buildConcernsTab(AppColorsScheme c) {
    final filtered =
        _concerns.where((x) => x['status'] == _concernFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(c, 'Concerns & Q&A',
            '${_concerns.where((x) => x['status'] == 'open').length} open'),
        // Status filter tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: ['open', 'in_review', 'resolved'].map((s) {
              final active = _concernFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _concernFilter = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF6366F1)
                          : c.surface1,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? const Color(0xFF6366F1)
                              : c.border),
                    ),
                    child: Text(_statusLabel(s),
                        style: TextStyle(
                          color: active ? Colors.white : c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _concernsLoading
              ? _skeletons()
              : filtered.isEmpty
                  ? Center(
                      child: Text('No $_concernFilter concerns',
                          style: TextStyle(
                              color: c.textMuted, fontSize: 14)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConcerns,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) =>
                            _concernCard(c, filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _concernCard(AppColorsScheme c, Map<String, dynamic> con) {
    final user = con['users'];
    final submitter = user is Map
        ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
        : 'Unknown';
    final prop = (con['properties'] is Map)
        ? con['properties']['name']?.toString() ?? ''
        : '';
    final ts = _fmtDate(con['created_at']?.toString() ?? '');

    return InkWell(
      onTap: () => _showConcernDetail(con, submitter),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(con['subject']?.toString() ?? 'No subject',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
              _statusChip(con['status']?.toString() ?? 'open'),
            ]),
            const SizedBox(height: 4),
            Text(con['message']?.toString() ?? '',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('$submitter${prop.isNotEmpty ? ' · $prop' : ''} · $ts',
                style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showConcernDetail(Map<String, dynamic> con, String submitter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _editSheet(
        title: con['subject']?.toString() ?? 'Concern',
        subtitle: 'From $submitter',
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(con['message']?.toString() ?? '',
                style:
                    const TextStyle(fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 20),
          _sheetLabel('UPDATE STATUS'),
          const SizedBox(height: 10),
          Row(children: [
            for (final s in ['open', 'in_review', 'resolved'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateConcernStatus(
                          con['id'].toString(), s);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _statusColor(s),
                      side: BorderSide(color: _statusColor(s)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_statusLabel(s),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  // ── Tools Tab ────────────────────────────────────────────────────────────────

  Widget _buildToolsTab(AppColorsScheme c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(c, 'Admin Tools', 'Management shortcuts'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              _toolSection(c, 'MANAGEMENT'),
              _toolTile(c,
                  icon: Icons.vpn_key_outlined,
                  color: const Color(0xFF6366F1),
                  title: 'Invite Codes',
                  subtitle: 'Generate and revoke invite codes per property',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminInviteCodesScreen(
                              properties: _properties)))),
              _toolTile(c,
                  icon: Icons.replay_outlined,
                  color: AppColors.warning,
                  title: 'Comeback Requests',
                  subtitle: 'Review and manage all pending comebacks',
                  onTap: () => _showComebacksScreen()),
              _toolTile(c,
                  icon: Icons.engineering_outlined,
                  color: AppColors.manager,
                  title: 'Worker Assignments',
                  subtitle: 'Assign and remove workers from properties',
                  onTap: () => _showWorkerAssignmentsScreen()),
              const SizedBox(height: 16),
              _toolSection(c, 'ACCOUNT'),
              _toolTile(c,
                  icon: Icons.lock_reset_outlined,
                  color: AppColors.info,
                  title: 'Change Password',
                  subtitle: 'Send a secure reset link to your email',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen()))),
              _toolTile(c,
                  icon: Icons.logout,
                  color: AppColors.error,
                  title: 'Sign Out',
                  subtitle: 'Sign out of the admin account',
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  }),
            ],
          ),
        ),
      ],
    );
  }

  void _showComebacksScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AdminComebacksScreen()),
    );
  }

  void _showWorkerAssignmentsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _AdminWorkerAssignmentsScreen(
              properties: _properties)),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────────

  Widget _header(AppColorsScheme c, String title, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(fontSize: 12, color: c.textMuted)),
          ],
        ),
      );

  Widget _filterChip(
          AppColorsScheme c, String label, bool active, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF6366F1) : c.surface1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? const Color(0xFF6366F1) : c.border),
            ),
            child: Text(label,
                style: TextStyle(
                  color: active ? Colors.white : c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      );

  Widget _rolePill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(
              color: _statusColor(status),
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _toolSection(AppColorsScheme c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
                letterSpacing: 1.2)),
      );

  Widget _toolTile(AppColorsScheme c,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletons() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: const [
          SkeletonCard(height: 70),
          SizedBox(height: 8),
          SkeletonCard(height: 70),
          SizedBox(height: 8),
          SkeletonCard(height: 70),
          SizedBox(height: 8),
          SkeletonCard(height: 70),
        ],
      );

  // ── Edit Sheet Template ───────────────────────────────────────────────────────

  Widget _editSheet({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label,
      {String? hint, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel(label.toUpperCase()),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Colors.black38, fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _sheetLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.black38,
          letterSpacing: 1.2));

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _fmtTime(dynamic pgTime) {
    if (pgTime == null) return '--';
    final parts = pgTime.toString().split(':');
    if (parts.length < 2) return pgTime.toString();
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final ap = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $ap';
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_review':
        return 'In Review';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Open';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'in_review':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }
}

// ── Admin Comebacks Screen ────────────────────────────────────────────────────

class _AdminComebacksScreen extends StatefulWidget {
  const _AdminComebacksScreen();

  @override
  State<_AdminComebacksScreen> createState() => _AdminComebacksScreenState();
}

class _AdminComebacksScreenState extends State<_AdminComebacksScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('missed_pickup_requests')
          .select(
              'id, status, is_free, payment_status, notes, requested_at, resident_user_id, users(first_name, last_name)')
          .order('requested_at', ascending: false);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('missed_pickup_requests')
          .update({'status': status}).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        _items.where((x) => x['status'] == _filter).toList();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Comeback Requests'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children:
                  ['pending', 'completed', 'cancelled'].map((s) {
                final active = _filter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF6366F1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? const Color(0xFF6366F1)
                                : Colors.grey.shade300),
                      ),
                      child: Text(
                        s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(
                            color: active
                                ? Colors.white
                                : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text('No $_filter comebacks',
                            style: const TextStyle(color: Colors.black38)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final item = filtered[i];
                            final user = item['users'];
                            final name = user is Map
                                ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                    .trim()
                                : 'Unknown';
                            final isFree = item['is_free'] == true;
                            final payStatus =
                                item['payment_status']?.toString() ?? 'free';
                            final ts = _fmtDate(
                                item['requested_at']?.toString() ?? '');
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 14))),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isFree
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                          isFree
                                              ? 'Free'
                                              : 'Paid · $payStatus',
                                          style: TextStyle(
                                              color: isFree
                                                  ? Colors.green.shade700
                                                  : Colors.orange
                                                      .shade700,
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                  ]),
                                  if ((item['notes']?.toString() ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item['notes'].toString(),
                                        style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12)),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(ts,
                                      style: const TextStyle(
                                          color: Colors.black38,
                                          fontSize: 11)),
                                  if (_filter == 'pending') ...[
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateStatus(
                                              item['id'].toString(),
                                              'completed'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green,
                                            side: const BorderSide(
                                                color: Colors.green),
                                          ),
                                          child: const Text('Complete'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateStatus(
                                              item['id'].toString(),
                                              'cancelled'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(
                                                color: Colors.red),
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Admin Worker Assignments Screen ──────────────────────────────────────────

class _AdminWorkerAssignmentsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> properties;
  const _AdminWorkerAssignmentsScreen({required this.properties});

  @override
  State<_AdminWorkerAssignmentsScreen> createState() =>
      _AdminWorkerAssignmentsScreenState();
}

class _AdminWorkerAssignmentsScreenState
    extends State<_AdminWorkerAssignmentsScreen> {
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _workers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final assigns = await Supabase.instance.client
          .from('worker_assignments')
          .select(
              'id, user_id, property_id, is_active, created_at, users(first_name, last_name, email), properties(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);
      final workers = await Supabase.instance.client
          .from('users')
          .select('id, first_name, last_name, email')
          .eq('role', 'driver');
      if (mounted) {
        setState(() {
          _assignments =
              List<Map<String, dynamic>>.from(assigns as List);
          _workers = List<Map<String, dynamic>>.from(workers as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeAssignment(String id) async {
    try {
      await Supabase.instance.client
          .from('worker_assignments')
          .update({'is_active': false}).eq('id', id);
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addAssignment(
      String userId, String propertyId) async {
    try {
      await Supabase.instance.client.from('worker_assignments').upsert({
        'user_id': userId,
        'property_id': propertyId,
        'is_active': true,
      }, onConflict: 'user_id,property_id');
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Worker assigned'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _showAddSheet() {
    String? workerId;
    String? propertyId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Worker Assignment',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: workerId,
                decoration: const InputDecoration(
                    labelText: 'Worker',
                    border: OutlineInputBorder()),
                items: _workers
                    .map((w) => DropdownMenuItem(
                          value: w['id'].toString(),
                          child: Text(
                              '${w['first_name']} ${w['last_name']}',
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setSheet(() => workerId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: propertyId,
                decoration: const InputDecoration(
                    labelText: 'Property',
                    border: OutlineInputBorder()),
                items: widget.properties
                    .map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['name'].toString(),
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setSheet(() => propertyId = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (workerId != null && propertyId != null)
                    ? () {
                        Navigator.pop(ctx);
                        _addAssignment(workerId!, propertyId!);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Assign Worker',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Worker Assignments'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddSheet),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _assignments.isEmpty
                  ? const Center(
                      child: Text('No active worker assignments',
                          style: TextStyle(color: Colors.black38)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _assignments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final a = _assignments[i];
                        final user = a['users'];
                        final name = user is Map
                            ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                .trim()
                            : 'Unknown';
                        final prop = (a['properties'] is Map)
                            ? a['properties']['name']
                                    ?.toString() ??
                                '?'
                            : '?';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.engineering_outlined,
                                  color: Color(0xFF6366F1), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(prop,
                                        style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => _removeAssignment(
                                    a['id'].toString()),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
