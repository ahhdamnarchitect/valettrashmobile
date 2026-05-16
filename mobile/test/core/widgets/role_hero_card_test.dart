import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/glow_badge.dart';
import 'package:mobile/core/widgets/role_hero_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        )),
      );

  group('RoleHeroCard', () {
    testWidgets('renders eyebrow, title, subtitle, and badge', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.resident,
          eyebrow: 'Tonight\'s Service',
          title: 'Sunset Gardens',
          subtitle: 'Unit 104',
          badgeLabel: 'Active',
        ),
      ));
      expect(find.text("TONIGHT'S SERVICE"), findsOneWidget); // uppercased
      expect(find.text('Sunset Gardens'), findsOneWidget);
      expect(find.text('Unit 104'), findsOneWidget);
      expect(find.byType(GlowBadge), findsOneWidget);
    });

    testWidgets('GlowBadge receives correct label', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.worker,
          eyebrow: 'Route',
          title: 'Sunset',
          subtitle: 'Unit 1',
          badgeLabel: 'On Route',
        ),
      ));
      expect(find.text('On Route'), findsOneWidget);
    });

    testWidgets('renders optional child widget when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.resident,
          eyebrow: 'Service',
          title: 'Gardens',
          subtitle: 'Unit 2',
          badgeLabel: 'Scheduled',
          child: Text('extra content'),
        ),
      ));
      expect(find.text('extra content'), findsOneWidget);
    });

    testWidgets('does not render child slot when child is null', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.resident,
          eyebrow: 'Service',
          title: 'Gardens',
          subtitle: 'Unit 3',
          badgeLabel: 'Scheduled',
        ),
      ));
      expect(find.text('extra content'), findsNothing);
    });
  });
}
