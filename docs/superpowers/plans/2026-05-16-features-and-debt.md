# Features & Technical Debt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four user-facing features (vacation hold, worker earnings, PM compliance report, OM live worker map) and clean up technical debt (withOpacity, dead code, .env.example, Supabase v2 upgrade).

**Architecture:** Features each add a new screen or extend an existing dashboard tab. All DB changes run first in the Supabase SQL editor. Supabase Realtime (`.stream()`) handles live worker locations. Flutter web's `dart:html` handles CSV download. Supabase v2 upgrade is last — it changes the pubspec and fixes any resulting type errors.

**Tech Stack:** Flutter 3.41.9 · Supabase Flutter v1→v2 · flutter_map (already installed) · dart:html (web only, for CSV export) · Supabase Realtime

---

## File Map

**New files:**
- `mobile/lib/features/resident/screens/resident_vacation_hold_screen.dart` — vacation hold toggle (navigated to from Profile tab)
- `mobile/lib/features/worker/screens/worker_earnings_screen.dart` — hours logged, pay period view
- `mobile/lib/features/manager/screens/pm_compliance_report_screen.dart` — PM service history + CSV export
- `mobile/lib/features/manager/screens/om_worker_map_screen.dart` — OM live worker location map
- `mobile/.env.example`

**Modified files:**
- `mobile/lib/features/resident/screens/resident_dashboard_screen.dart:809` — add "Vacation Hold" row to Profile tab
- `mobile/lib/features/worker/screens/worker_dashboard_screen.dart:320` — persist clock events to DB; add Earnings link in Profile tab
- `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart:750` — add "Compliance Report" button in Settings tab
- `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` — add "Live Worker Map" button in Dashboard tab; delete `_legacyBuild()` (line 1051)
- `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart:1043` — delete `_buildLegacyDashboard()`
- 23 dart files — `withOpacity()` → `.withValues(alpha:)` via PowerShell
- `mobile/pubspec.yaml` — supabase_flutter: ^1.10.25 → ^2.8.0

---

## Task 1: DB Schema — Run in Supabase SQL Editor

**Files:** No Dart files. Run SQL in https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft/sql/new

- [ ] **Step 1: Run the SQL**

```sql
-- Vacation hold flag on resident_units
ALTER TABLE resident_units
  ADD COLUMN IF NOT EXISTS is_on_hold boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS hold_note text;

-- Clock events for worker time tracking
CREATE TABLE IF NOT EXISTS clock_events (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  property_id uuid REFERENCES properties(id),
  event_type  text NOT NULL CHECK (event_type IN ('clock_in', 'clock_out')),
  created_at  timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE clock_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "workers_own_clock_events" ON clock_events
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "managers_read_clock_events" ON clock_events
  FOR SELECT USING (true);

-- Worker live locations (upsert pattern — one row per worker)
CREATE TABLE IF NOT EXISTS worker_locations (
  user_id     uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id),
  latitude    double precision NOT NULL,
  longitude   double precision NOT NULL,
  updated_at  timestamptz DEFAULT now() NOT NULL
);
ALTER TABLE worker_locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "workers_own_location" ON worker_locations
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "managers_read_locations" ON worker_locations
  FOR SELECT USING (true);
```

- [ ] **Step 2: Verify**

In the Supabase Table Editor, confirm `resident_units` now has `is_on_hold` and `hold_note` columns, and that `clock_events` and `worker_locations` tables exist.

- [ ] **Step 3: Commit**

```
git add -A
git commit -m "docs: add schema SQL for vacation hold, clock events, worker locations"
```

---

## Task 2: Resident Vacation Hold

**Files:**
- Create: `mobile/lib/features/resident/screens/resident_vacation_hold_screen.dart`
- Modify: `mobile/lib/features/resident/screens/resident_dashboard_screen.dart` (Profile tab, ~line 815)

- [ ] **Step 1: Create the vacation hold screen**

```dart
// mobile/lib/features/resident/screens/resident_vacation_hold_screen.dart
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
```

- [ ] **Step 2: Add "Vacation Hold" row to Resident Profile tab**

In `mobile/lib/features/resident/screens/resident_dashboard_screen.dart`, find `_buildProfileTab()` (~line 809). Add this import at the top of the file:

```dart
import 'resident_vacation_hold_screen.dart';
```

Then inside `_buildProfileTab()`, before the sign-out section, add:

```dart
// Vacation hold row — add after the profile header section
ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.beach_access_outlined,
        color: AppColors.warning, size: 20),
  ),
  title: const Text('Vacation Hold',
      style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600)),
  subtitle: const Text('Pause pickups while away',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  trailing: const Icon(Icons.chevron_right,
      color: AppColors.textMuted, size: 20),
  onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const ResidentVacationHoldScreen())),
),
const Divider(color: AppColors.border, height: 1),
```

- [ ] **Step 3: Build and verify**

```powershell
cd C:\Users\e159305\Projects\valettrashmobile\mobile
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" build web --no-tree-shake-icons 2>&1 | Select-Object -Last 3
```
Expected: `√ Built build\web`

- [ ] **Step 4: Commit**

```
git add mobile/lib/features/resident/screens/resident_vacation_hold_screen.dart
git add mobile/lib/features/resident/screens/resident_dashboard_screen.dart
git commit -m "feat: resident vacation hold — pause pickups while away"
```

---

## Task 3: Worker Clock Event Persistence + Earnings Screen

**Files:**
- Create: `mobile/lib/features/worker/screens/worker_earnings_screen.dart`
- Modify: `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` (~line 320)

- [ ] **Step 1: Wire clock in/out to persist clock_events**

In `mobile/lib/features/worker/screens/worker_dashboard_screen.dart`, find the toggle method around line 320 that sets `_isOnDuty`. Replace the body with:

```dart
Future<void> _toggleDuty() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  final newState = !_isOnDuty;
  setState(() => _isOnDuty = newState);
  try {
    await Supabase.instance.client.from('clock_events').insert({
      'user_id': uid,
      'event_type': newState ? 'clock_in' : 'clock_out',
      'property_id': _propertyId,
    });
  } catch (_) {
    // Non-blocking — UI state already updated
  }
  _snack(newState ? 'You are now on duty' : 'You are now off duty');
}
```

You also need `_propertyId` — add it as a state field and capture it during `_load()` where property assignments are fetched:

```dart
String? _propertyId; // add to state fields

// In _load(), after fetching worker_assignments:
// assigns is already fetched — add:
if (assigns.isNotEmpty) {
  _propertyId = assigns.first['property_id']?.toString();
}
```

Change the existing clock button's `onPressed` from `() { setState(() => _isOnDuty = !_isOnDuty); _snack(...); }` to `_toggleDuty`.

- [ ] **Step 2: Create worker earnings screen**

```dart
// mobile/lib/features/worker/screens/worker_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stat_tile.dart';

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({super.key});

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];

  double get _weekHours => _computeHours(_weekStart);
  double get _monthHours => _computeHours(_monthStart);

  DateTime get _weekStart {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  double _computeHours(DateTime since) {
    double total = 0;
    DateTime? lastIn;
    for (final e in _events) {
      final ts = DateTime.parse(e['created_at'] as String).toLocal();
      if (ts.isBefore(since)) continue;
      if (e['event_type'] == 'clock_in') {
        lastIn = ts;
      } else if (e['event_type'] == 'clock_out' && lastIn != null) {
        total += ts.difference(lastIn).inMinutes / 60.0;
        lastIn = null;
      }
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();
    final rows = await Supabase.instance.client
        .from('clock_events')
        .select('event_type, created_at')
        .eq('user_id', uid)
        .gte('created_at', since)
        .order('created_at', ascending: true);
    if (mounted) {
      setState(() {
        _events = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    }
  }

  String _fmt(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  String _fmtTs(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
        title: const Text('Earnings',
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                Row(children: [
                  StatTile(
                      value: _fmt(_weekHours), label: 'This Week'),
                  const SizedBox(width: 8),
                  StatTile(
                      value: _fmt(_monthHours), label: 'This Month'),
                ]),
                const SizedBox(height: 28),
                const Text('CLOCK HISTORY — LAST 30 DAYS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  const Text('No clock events yet.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14))
                else
                  ..._buildPairs(),
              ],
            ),
    );
  }

  List<Widget> _buildPairs() {
    final widgets = <Widget>[];
    DateTime? lastIn;
    String? lastInTs;
    for (final e in _events.reversed) {
      final isIn = e['event_type'] == 'clock_in';
      if (isIn) {
        lastIn = DateTime.parse(e['created_at'] as String).toLocal();
        lastInTs = e['created_at'] as String;
      } else if (!isIn && lastIn != null) {
        final out = DateTime.parse(e['created_at'] as String).toLocal();
        final hours = out.difference(lastIn).inMinutes / 60.0;
        widgets.add(_shiftTile(_fmtTs(lastInTs!), _fmtTs(e['created_at'] as String), _fmt(hours)));
        lastIn = null;
      }
    }
    if (lastIn != null) {
      widgets.add(_shiftTile(_fmtTs(lastInTs!), 'Still clocked in', '—'));
    }
    return widgets;
  }

  Widget _shiftTile(String inTime, String outTime, String duration) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_outlined,
              color: AppColors.worker, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('In: $inTime',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('Out: $outTime',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(duration,
              style: const TextStyle(
                  color: AppColors.worker,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Add Earnings link to Worker Profile tab**

In `mobile/lib/features/worker/screens/worker_dashboard_screen.dart`, add this import at the top:

```dart
import 'worker_earnings_screen.dart';
```

In `_buildProfileTab()`, before the sign-out section, add:

```dart
ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: AppColors.worker.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.attach_money_outlined,
        color: AppColors.worker, size: 20),
  ),
  title: const Text('Earnings & Hours',
      style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600)),
  subtitle: const Text('Clock history and weekly totals',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  trailing: const Icon(Icons.chevron_right,
      color: AppColors.textMuted, size: 20),
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const WorkerEarningsScreen())),
),
const Divider(color: AppColors.border, height: 1),
```

- [ ] **Step 4: Build and verify**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" build web --no-tree-shake-icons 2>&1 | Select-Object -Last 3
```
Expected: `√ Built build\web`

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/worker/screens/worker_earnings_screen.dart
git add mobile/lib/features/worker/screens/worker_dashboard_screen.dart
git commit -m "feat: worker clock event persistence + earnings dashboard"
```

---

## Task 4: PM Compliance / SLA Report

**Files:**
- Create: `mobile/lib/features/manager/screens/pm_compliance_report_screen.dart`
- Modify: `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart` (Settings tab ~line 750)

- [ ] **Step 1: Create the compliance report screen**

```dart
// mobile/lib/features/manager/screens/pm_compliance_report_screen.dart
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
    final toStr =
        DateTime(_to.year, _to.month, _to.day, 23, 59, 59)
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
      final started = r['started_at'] != null
          ? _fmtTs(r['started_at'] as String)
          : '';
      final completed = r['completed_at'] != null
          ? _fmtTs(r['completed_at'] as String)
          : '';
      buf.writeln('$date,$status,$started,$completed');
    }
    final content = buf.toString();
    final blob = html.Blob([content], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.document.createElement('a')
        as html.AnchorElement
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
          // Date range bar
          Container(
            color: AppColors.surface1,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _dateChip('From', _from, (d) {
                  setState(() => _from = d);
                  _load();
                }),
                const SizedBox(width: 8),
                const Text('→',
                    style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(width: 8),
                _dateChip('To', _to, (d) {
                  setState(() => _to = d);
                  _load();
                }),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
                                color: AppColors.textSecondary,
                                fontSize: 14)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
                              border:
                                  Border.all(color: AppColors.border),
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
                                            r['created_at'] as String? ??
                                                ''),
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      if (r['started_at'] != null)
                                        Text(
                                          '${_fmtTs(r['started_at'] as String)} → ${r['completed_at'] != null ? _fmtTs(r['completed_at'] as String) : 'ongoing'}',
                                          style: const TextStyle(
                                              color:
                                                  AppColors.textSecondary,
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
                                    borderRadius:
                                        BorderRadius.circular(8),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '$label: ${_fmtDate(value.toIso8601String())}',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add "Compliance Report" to PM Settings tab**

In `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart`, add this import at the top:

```dart
import 'pm_compliance_report_screen.dart';
```

In `_buildSettingsTab()` (around line 750), before the sign-out section, add a compliance report section. Find the settings ListView children and add:

```dart
// Compliance Reports section header
const SizedBox(height: 20),
Text('REPORTS', style: TextStyle(
  fontSize: 11, fontWeight: FontWeight.w700,
  color: _c.textMuted, letterSpacing: 1.2)),
const SizedBox(height: 10),
// One card per property
..._properties.map((p) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: ListTile(
    tileColor: _c.surface1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: _c.border),
    ),
    leading: Icon(Icons.bar_chart_outlined, color: AppColors.manager, size: 22),
    title: Text(p['name']?.toString() ?? '',
        style: TextStyle(color: _c.textPrimary,
            fontSize: 14, fontWeight: FontWeight.w600)),
    subtitle: Text('Service history & SLA',
        style: TextStyle(color: _c.textSecondary, fontSize: 12)),
    trailing: Icon(Icons.chevron_right, color: _c.textMuted, size: 20),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => PmComplianceReportScreen(
        propertyId: p['id']?.toString() ?? '',
        propertyName: p['name']?.toString() ?? '',
      ),
    )),
  ),
)),
const SizedBox(height: 12),
```

- [ ] **Step 3: Build and verify**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" build web --no-tree-shake-icons 2>&1 | Select-Object -Last 3
```

- [ ] **Step 4: Commit**

```
git add mobile/lib/features/manager/screens/pm_compliance_report_screen.dart
git add mobile/lib/features/manager/screens/property_manager_dashboard_new.dart
git commit -m "feat: PM compliance/SLA report screen with CSV export"
```

---

## Task 5: OM Live Worker Location Map

**Files:**
- Create: `mobile/lib/features/manager/screens/om_worker_map_screen.dart`
- Modify: `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` (add location sharing button)
- Modify: `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` (add map button in Dashboard tab)

- [ ] **Step 1: Create the OM live map screen**

```dart
// mobile/lib/features/manager/screens/om_worker_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';

class OmWorkerMapScreen extends StatefulWidget {
  const OmWorkerMapScreen({super.key});

  @override
  State<OmWorkerMapScreen> createState() => _OmWorkerMapScreenState();
}

class _OmWorkerMapScreenState extends State<OmWorkerMapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  Stream<List<Map<String, dynamic>>>? _stream;

  static const _center = LatLng(37.09, -95.71);

  @override
  void initState() {
    super.initState();
    _stream = Supabase.instance.client
        .from('worker_locations')
        .stream(primaryKey: ['user_id'])
        .map((rows) => List<Map<String, dynamic>>.from(rows));
    _stream!.listen((rows) {
      if (mounted) {
        setState(() {
          _locations = rows;
          _loading = false;
        });
      }
    });
  }

  LatLng _mapCenter() {
    if (_locations.isEmpty) return _center;
    final lats =
        _locations.map((l) => (l['latitude'] as num).toDouble()).toList();
    final lngs =
        _locations.map((l) => (l['longitude'] as num).toDouble()).toList();
    return LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lngs.reduce((a, b) => a + b) / lngs.length,
    );
  }

  String _ago(String? iso) {
    if (iso == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
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
        title: const Text('Live Worker Map',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GlowBadge(
              label: '${_locations.length} online',
              accent: AppColors.worker,
              showDot: _locations.isNotEmpty,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter(),
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.valettrash.mobile',
                      ),
                      MarkerLayer(
                        markers: _locations.map((loc) {
                          final lat =
                              (loc['latitude'] as num).toDouble();
                          final lng =
                              (loc['longitude'] as num).toDouble();
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.worker,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.worker
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 20),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface1,
                      border: Border(
                          top: BorderSide(color: AppColors.border)),
                    ),
                    child: _locations.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_off_outlined,
                                    color: AppColors.textMuted, size: 32),
                                SizedBox(height: 8),
                                Text('No workers sharing location',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14)),
                                SizedBox(height: 4),
                                Text(
                                    'Workers share their location from the Route tab.',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16, 12, 16, 16),
                            itemCount: _locations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final loc = _locations[i];
                              return Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.worker
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person,
                                        color: AppColors.worker,
                                        size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Worker ${(loc['user_id'] as String).substring(0, 8)}…',
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    _ago(loc['updated_at'] as String?),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 2: Add location sharing to Worker Route tab**

In `mobile/lib/features/worker/screens/worker_dashboard_screen.dart`, add this import:

```dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
```

Add this method to the State class:

```dart
Future<void> _shareLocation() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final pos = await html.window.navigator.geolocation
        .getCurrentPosition()
        .timeout(const Duration(seconds: 10));
    final lat = pos.coords!.latitude!.toDouble();
    final lng = pos.coords!.longitude!.toDouble();
    await Supabase.instance.client.from('worker_locations').upsert({
      'user_id': uid,
      'property_id': _propertyId,
      'latitude': lat,
      'longitude': lng,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    _snack('Location shared');
  } catch (e) {
    _snack('Could not get location: $e');
  }
}
```

In the Route tab build, after the "View Route Map" button, add:

```dart
const SizedBox(height: 10),
OutlinedButton.icon(
  onPressed: _isOnDuty ? _shareLocation : null,
  icon: const Icon(Icons.my_location, size: 16),
  label: const Text('Share My Location'),
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.worker,
    side: const BorderSide(color: AppColors.worker),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
),
```

- [ ] **Step 3: Add "Live Worker Map" button to OM Dashboard tab**

In `mobile/lib/features/manager/screens/manager_dashboard_screen.dart`, add this import:

```dart
import 'om_worker_map_screen.dart';
```

In the OM Dashboard tab build method, add a button after the tonight's runs section:

```dart
OutlinedButton.icon(
  onPressed: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const OmWorkerMapScreen())),
  icon: const Icon(Icons.map_outlined, size: 16),
  label: const Text('Live Worker Map'),
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.manager,
    side: const BorderSide(color: AppColors.manager),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
),
```

- [ ] **Step 4: Build and verify**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" build web --no-tree-shake-icons 2>&1 | Select-Object -Last 3
```

- [ ] **Step 5: Commit**

```
git add mobile/lib/features/manager/screens/om_worker_map_screen.dart
git add mobile/lib/features/worker/screens/worker_dashboard_screen.dart
git add mobile/lib/features/manager/screens/manager_dashboard_screen.dart
git commit -m "feat: OM live worker location map + worker location sharing"
```

---

## Task 6: Technical Debt — withOpacity → withValues

**Files:** 23 dart files (global replace via PowerShell)

- [ ] **Step 1: Replace withOpacity with withValues across all Dart files**

```powershell
$libDir = "C:\Users\e159305\Projects\valettrashmobile\mobile\lib"
Get-ChildItem -Path $libDir -Recurse -Filter "*.dart" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    if ($content -match 'withOpacity\(') {
        $updated = $content -replace '\.withOpacity\(([^)]+)\)', '.withValues(alpha: $1)'
        [System.IO.File]::WriteAllText($_.FullName, $updated, [System.Text.Encoding]::UTF8)
        Write-Output "Updated: $($_.Name)"
    }
}
```

- [ ] **Step 2: Verify — count remaining withOpacity calls**

```powershell
Select-String -Path "$libDir\**\*.dart" -Pattern 'withOpacity' -Recurse | Measure-Object | Select-Object -ExpandProperty Count
```
Expected: `0`

- [ ] **Step 3: Build to confirm no regressions**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" build web --no-tree-shake-icons 2>&1 | Select-Object -Last 3
```

- [ ] **Step 4: Commit**

```
git add -A
git commit -m "refactor: replace withOpacity() with withValues(alpha:) throughout"
```

---

## Task 7: Technical Debt — Remove Dead Code

**Files:**
- Modify: `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` (delete `_legacyBuild` at line 1051)
- Modify: `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart` (delete `_buildLegacyDashboard` at line 1043)

- [ ] **Step 1: Delete `_legacyBuild` from OM dashboard**

In `manager_dashboard_screen.dart`, find `Widget _legacyBuild(BuildContext context) {` at line 1051. Delete from that line to the matching closing `}` of the method. The method is unreferenced — the analyzer warns about it.

To find its end:
```powershell
$f = "C:\Users\e159305\Projects\valettrashmobile\mobile\lib\features\manager\screens\manager_dashboard_screen.dart"
(Get-Content $f)[(1051-1)..1634] | Select-Object -First 5
```
Read those lines and manually delete the dead method via the Edit tool.

- [ ] **Step 2: Delete `_buildLegacyDashboard` from PM dashboard**

Same approach in `property_manager_dashboard_new.dart` at line 1043.

- [ ] **Step 3: Build and verify zero errors**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" analyze --no-congratulate 2>&1 | Where-Object { $_ -match "^\s+error " }
```
Expected: no output (zero errors).

- [ ] **Step 4: Commit**

```
git add mobile/lib/features/manager/screens/manager_dashboard_screen.dart
git add mobile/lib/features/manager/screens/property_manager_dashboard_new.dart
git commit -m "refactor: remove dead _legacyBuild and _buildLegacyDashboard methods"
```

---

## Task 8: Technical Debt — Add .env.example

**Files:**
- Create: `mobile/.env.example`

- [ ] **Step 1: Create the file**

```
# mobile/.env.example
# Copy this file to .env and fill in your values.
# Get these from: https://supabase.com/dashboard/project/<ref>/settings/api

SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

- [ ] **Step 2: Commit**

```
git add mobile/.env.example
git commit -m "docs: add .env.example for developer onboarding"
```

---

## Task 9: Supabase Flutter v1 → v2 Upgrade

> ⚠️ **Highest risk task. Do last. Test every role dashboard after upgrading.**

**Files:**
- Modify: `mobile/pubspec.yaml`
- Potentially many dart files (fix compile errors as they appear)

Key v2 breaking changes relevant to this codebase:
- `supabase_flutter: ^1.10.25` → `^2.8.0`
- `.select()` now returns `List<Map<String, dynamic>>` directly (no more `PostgrestList` cast dance — but `as List` casts should still work)
- `.stream(primaryKey: [...])` API unchanged in v2
- Auth: `signInWithPassword` already used ✓
- `storage.from().uploadBinary()` → `storage.from().uploadBinary()` (unchanged)
- `storage.from().getPublicUrl()` → unchanged

- [ ] **Step 1: Upgrade pubspec**

In `mobile/pubspec.yaml`, change:
```yaml
supabase_flutter: ^1.10.25
```
to:
```yaml
supabase_flutter: ^2.8.0
```

- [ ] **Step 2: Run pub get**

```powershell
cd C:\Users\e159305\Projects\valettrashmobile\mobile
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" pub get
```

- [ ] **Step 3: Analyze for errors**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" analyze --no-congratulate 2>&1 | Where-Object { $_ -match "^\s+error " }
```

Fix any errors that appear. Common fixes:
- If `PostgrestResponse` is referenced anywhere: remove it, use the query result directly
- If `.execute()` is called anywhere: remove `.execute()`, the result IS the response

- [ ] **Step 4: Build**

```powershell
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" build web --no-tree-shake-icons 2>&1 | Select-Object -Last 5
```

- [ ] **Step 5: Test all 5 role dashboards manually**

Sign in as each test account and verify the dashboard loads:
- `adam.grant824+res2@gmail.com` → Resident dashboard
- `adam.grant824+pm@gmail.com` → PM dashboard (light mode)
- `adam.grant824+om@gmail.com` → OM dashboard
- `adam.grant824+worker@gmail.com` → Worker dashboard
- Owner (super_admin) account → Owner dashboard (light mode)

- [ ] **Step 6: Commit**

```
git add mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "chore: upgrade supabase_flutter v1 → v2"
```

---

## Self-Review

**Spec coverage:**
- ✅ Resident vacation hold — Task 2 (screen + Profile tab row)
- ✅ Worker earnings — Task 3 (clock events persisted + earnings screen)
- ✅ PM compliance report — Task 4 (screen + CSV export + Settings tab entry)
- ✅ OM live worker map — Task 5 (map screen + worker location sharing + OM button)
- ✅ withOpacity → withValues — Task 6
- ✅ Dead code removal — Task 7
- ✅ .env.example — Task 8
- ✅ Supabase v2 upgrade — Task 9

**Placeholder scan:** No TBDs. All code blocks are complete.

**Type consistency:**
- `_propertyId: String?` used in Task 3 (clock events) and Task 5 (location sharing) — consistent
- `AppColorsScheme _c` used in PM dashboard — Task 4 correctly uses `_c.*` for colors in the Settings tab addition
- `worker_locations` table primary key is `user_id` — Realtime stream uses `primaryKey: ['user_id']` ✓
