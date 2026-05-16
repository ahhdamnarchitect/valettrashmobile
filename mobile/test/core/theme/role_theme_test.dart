import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/role_theme.dart';

void main() {
  group('RoleTheme.accentFor', () {
    test('resident returns emerald', () {
      expect(RoleTheme.accentFor(AppRole.resident), AppColors.resident);
    });

    test('worker returns amber', () {
      expect(RoleTheme.accentFor(AppRole.worker), AppColors.worker);
    });

    test('propertyManager returns indigo', () {
      expect(RoleTheme.accentFor(AppRole.propertyManager), AppColors.manager);
    });

    test('operationsManager returns indigo (same as PM)', () {
      expect(RoleTheme.accentFor(AppRole.operationsManager), AppColors.manager);
    });

    test('owner returns purple', () {
      expect(RoleTheme.accentFor(AppRole.owner), AppColors.owner);
    });
  });

  group('RoleTheme.fromString', () {
    test('maps resident string', () {
      expect(RoleTheme.fromString('resident'), AppRole.resident);
    });

    test('maps driver string to worker role', () {
      expect(RoleTheme.fromString('driver'), AppRole.worker);
    });

    test('maps property_manager string', () {
      expect(RoleTheme.fromString('property_manager'), AppRole.propertyManager);
    });

    test('maps operations_manager string', () {
      expect(RoleTheme.fromString('operations_manager'), AppRole.operationsManager);
    });

    test('maps super_admin string to owner role', () {
      expect(RoleTheme.fromString('super_admin'), AppRole.owner);
    });

    test('unknown string defaults to resident', () {
      expect(RoleTheme.fromString('unknown_role'), AppRole.resident);
    });
  });
}
