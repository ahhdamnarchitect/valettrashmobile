import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RoleNavItem {
  const RoleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class RoleBottomNav extends StatelessWidget {
  const RoleBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.accent,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<RoleNavItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.roleColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface1,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? accent.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 22,
                          color: isActive ? accent : c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive ? accent : c.textMuted,
                          letterSpacing: 0.02,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
