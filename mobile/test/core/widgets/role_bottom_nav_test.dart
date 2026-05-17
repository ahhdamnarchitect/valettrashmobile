import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/role_bottom_nav.dart';

void main() {
  final items = const [
    RoleNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    RoleNavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
    RoleNavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
  ];

  Widget wrap({required int currentIndex, required ValueChanged<int> onTap}) =>
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: RoleBottomNav(
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
            accent: AppColors.resident,
          ),
        ),
      );

  group('RoleBottomNav', () {
    testWidgets('renders all item labels', (tester) async {
      await tester.pumpWidget(wrap(currentIndex: 0, onTap: (_) {}));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
    });

    testWidgets('calls onTap with correct index', (tester) async {
      int? tapped;
      await tester.pumpWidget(wrap(currentIndex: 0, onTap: (i) => tapped = i));
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('tapping third item calls onTap with index 2', (tester) async {
      int? tapped;
      await tester.pumpWidget(wrap(currentIndex: 0, onTap: (i) => tapped = i));
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      expect(tapped, 2);
    });
  });
}
