import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppRole {
  resident,
  worker,
  propertyManager,
  operationsManager,
  owner,
}

abstract final class RoleTheme {
  static Color accentFor(AppRole role) => switch (role) {
    AppRole.resident           => AppColors.resident,
    AppRole.worker             => AppColors.worker,
    AppRole.propertyManager    => AppColors.manager,
    AppRole.operationsManager  => AppColors.manager,
    AppRole.owner              => AppColors.owner,
  };

  static AppRole fromString(String role) => switch (role) {
    'resident'           => AppRole.resident,
    'driver'             => AppRole.worker,
    'property_manager'   => AppRole.propertyManager,
    'operations_manager' => AppRole.operationsManager,
    'super_admin'        => AppRole.owner,
    _                    => AppRole.resident,
  };
}
