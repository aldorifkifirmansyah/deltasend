import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_home_screen.dart';
import 'admin_order_list_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_tracking_list_screen.dart';
import 'admin_users_screen.dart';

class AdminBottomBar extends StatelessWidget {
  final int selectedIndex;

  const AdminBottomBar({super.key, required this.selectedIndex});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _inactiveColor = Color(0xFFAFC4E8);

  void _openPage(BuildContext context, int index) {
    if (index == selectedIndex) {
      return;
    }

    late final Widget destination;

    switch (index) {
      case 0:
        destination = const AdminHomeScreen();
        break;

      case 1:
        destination = const AdminUsersScreen();
        break;

      case 2:
        destination = const AdminOrdersScreen();
        break;

      case 3:
        destination = const AdminTrackingListScreen();
        break;

      case 4:
        destination = const AdminProfileScreen();
        break;

      default:
        return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return destination;
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _AdminBottomItem(
                icon: Icons.home_rounded,
                label: 'Dashboard',
                active: selectedIndex == 0,
                onTap: () => _openPage(context, 0),
              ),
              _AdminBottomItem(
                icon: Icons.groups_rounded,
                label: 'Users',
                active: selectedIndex == 1,
                onTap: () => _openPage(context, 1),
              ),
              _AdminBottomItem(
                icon: Icons.inventory_2_rounded,
                label: 'Orders',
                active: selectedIndex == 2,
                onTap: () => _openPage(context, 2),
              ),
              _AdminBottomItem(
                icon: Icons.route_rounded,
                label: 'Tracking',
                active: selectedIndex == 3,
                onTap: () => _openPage(context, 3),
              ),
              _AdminBottomItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                active: selectedIndex == 4,
                onTap: () => _openPage(context, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _AdminBottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = active ? Colors.white : AdminBottomBar._inactiveColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 27),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
