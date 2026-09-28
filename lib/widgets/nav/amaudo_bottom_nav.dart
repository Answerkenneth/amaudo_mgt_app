import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// WhatsApp-inspired 4-item bottom navigation using Amaudo's own
/// palette (never WhatsApp green). Notifications is intentionally
/// not included here — it lives in the app bar's top-right corner
/// (swapped with Settings; see AppShell). Tapping the Settings item
/// below pushes SettingsScreen exactly as the old app bar button
/// did — it does not change `currentIndex`.
class AmaudoBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AmaudoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItemData> _items = [
    _NavItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItemData(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    _NavItemData(
      label: 'Appointments',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    _NavItemData(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = index == currentIndex;

              return Expanded(
                child: Semantics(
                  label: item.label,
                  selected: selected,
                  button: true,
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: selected
                              ? AppColors.primaryOrange
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppColors.primaryOrange
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
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