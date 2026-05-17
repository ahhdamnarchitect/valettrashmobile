import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminInviteCodesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> properties;

  const AdminInviteCodesScreen({super.key, required this.properties});

  @override
  State<AdminInviteCodesScreen> createState() =>
      _AdminInviteCodesScreenState();
}

class _AdminInviteCodesScreenState extends State<AdminInviteCodesScreen> {
  List<Map<String, dynamic>> _codes = [];
  List<Map<String, dynamic>> _units = [];
  bool _loading = true;
  String? _propFilter;

  @override
  void initState() {
    super.initState();
    if (widget.properties.isNotEmpty) {
      _propFilter = widget.properties.first['id']?.toString();
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var query = Supabase.instance.client
          .from('invite_codes')
          .select(
              'id, code, property_id, unit_id, max_uses, current_uses, expires_at, is_active, properties(name), units(unit_number)');

      if (_propFilter != null) {
        query = query.eq('property_id', _propFilter!);
      }

      final rows = await query.order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _codes = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnits(String propertyId) async {
    try {
      final rows = await Supabase.instance.client
          .from('units')
          .select('id, unit_number')
          .eq('property_id', propertyId)
          .order('unit_number');
      if (mounted) {
        setState(() {
          _units = List<Map<String, dynamic>>.from(rows as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _revokeCode(String id) async {
    try {
      await Supabase.instance.client
          .from('invite_codes')
          .update({'is_active': false}).eq('id', id);
      _load();
      _snack('Code revoked');
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Future<void> _generateCode({
    required String propertyId,
    required String unitId,
    required int maxUses,
    required int daysValid,
  }) async {
    final code = _randomCode();
    final expires = DateTime.now()
        .add(Duration(days: daysValid))
        .toUtc()
        .toIso8601String();
    try {
      await Supabase.instance.client.from('invite_codes').insert({
        'code': code,
        'property_id': propertyId,
        'unit_id': unitId,
        'max_uses': maxUses,
        'current_uses': 0,
        'expires_at': expires,
        'is_active': true,
        'created_by': Supabase.instance.client.auth.currentUser?.id,
      });
      _load();
      _snack('Code $code generated');
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _showGenerateSheet() {
    String? propertyId = _propFilter ?? widget.properties.first['id']?.toString();
    String? unitId;
    int maxUses = 1;
    int daysValid = 365;

    if (propertyId != null) _loadUnits(propertyId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Generate Invite Code',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Property
              DropdownButtonFormField<String>(
                value: propertyId,
                decoration: const InputDecoration(
                    labelText: 'Property', border: OutlineInputBorder()),
                items: widget.properties
                    .map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['name'].toString(),
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) {
                  setSheet(() {
                    propertyId = v;
                    unitId = null;
                    _units = [];
                  });
                  if (v != null) _loadUnits(v);
                },
              ),
              const SizedBox(height: 12),

              // Unit
              StatefulBuilder(builder: (ctx2, setUnit) {
                return DropdownButtonFormField<String>(
                  value: unitId,
                  decoration: const InputDecoration(
                      labelText: 'Unit', border: OutlineInputBorder()),
                  items: _units
                      .map((u) => DropdownMenuItem(
                            value: u['id'].toString(),
                            child: Text(
                                'Unit ${u['unit_number']}',
                                style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (v) => setSheet(() => unitId = v),
                );
              }),
              const SizedBox(height: 12),

              // Max uses
              Row(children: [
                const Expanded(
                    child: Text('Max Uses',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500))),
                DropdownButton<int>(
                  value: maxUses,
                  items: [1, 2, 5, 10, 25]
                      .map((n) => DropdownMenuItem(
                          value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) =>
                      setSheet(() => maxUses = v ?? 1),
                ),
              ]),

              // Days valid
              Row(children: [
                const Expanded(
                    child: Text('Valid For',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500))),
                DropdownButton<int>(
                  value: daysValid,
                  items: [
                    const DropdownMenuItem(value: 30, child: Text('30 days')),
                    const DropdownMenuItem(value: 90, child: Text('90 days')),
                    const DropdownMenuItem(
                        value: 365, child: Text('1 year')),
                    const DropdownMenuItem(
                        value: 730, child: Text('2 years')),
                  ],
                  onChanged: (v) =>
                      setSheet(() => daysValid = v ?? 365),
                ),
              ]),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (propertyId != null && unitId != null)
                    ? () {
                        Navigator.pop(ctx);
                        _generateCode(
                          propertyId: propertyId!,
                          unitId: unitId!,
                          maxUses: maxUses,
                          daysValid: daysValid,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Generate Code',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Invite Codes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showGenerateSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Property filter
          if (widget.properties.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: widget.properties.map((p) {
                  final active =
                      _propFilter == p['id']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() =>
                            _propFilter = p['id']?.toString());
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
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
                        child: Text(p['name'].toString(),
                            style: TextStyle(
                              color:
                                  active ? Colors.white : Colors.black54,
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _codes.isEmpty
                    ? const Center(
                        child: Text('No invite codes for this property.',
                            style: TextStyle(color: Colors.black38)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _codes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final c = _codes[i];
                            final code = c['code']?.toString() ?? '';
                            final unit = (c['units'] is Map)
                                ? 'Unit ${c['units']['unit_number']}'
                                : '?';
                            final uses =
                                '${c['current_uses'] ?? 0}/${c['max_uses'] ?? 0} uses';
                            final active = c['is_active'] == true;
                            final expStr = _fmtDate(
                                c['expires_at']?.toString() ?? '');

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: active
                                        ? Colors.grey.shade200
                                        : Colors.red.shade100),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(
                                            code,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight:
                                                  FontWeight.w800,
                                              letterSpacing: 2,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!active)
                                            const Text('REVOKED',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text(
                                            '$unit  ·  $uses  ·  Expires $expStr',
                                            style: const TextStyle(
                                                color: Colors.black45,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_outlined,
                                        size: 18, color: Colors.black38),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: code));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Code copied')));
                                    },
                                  ),
                                  if (active)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.block_outlined,
                                          size: 18,
                                          color: Colors.red),
                                      onPressed: () => _revokeCode(
                                          c['id'].toString()),
                                    ),
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
      return '—';
    }
  }
}
