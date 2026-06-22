import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'customer_home_screen.dart';

class CustomerBottomBar extends StatelessWidget {
  final int selectedIndex;

  const CustomerBottomBar({super.key, required this.selectedIndex});

  static const Color _primaryBlue = Color(0xFF133D87);

  void _openTab(BuildContext context, int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => CustomerHomeScreen(initialIndex: index),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _BottomItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => _openTab(context, 0),
              ),
              _BottomItem(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                selected: selectedIndex == 1,
                onTap: () => _openTab(context, 1),
              ),
              _BottomItem(
                icon: Icons.forum_outlined,
                label: 'Chat',
                selected: selectedIndex == 2,
                onTap: () => _openTab(context, 2),
              ),
              _BottomItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                selected: selectedIndex == 3,
                onTap: () => _openTab(context, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = selected ? Colors.white : const Color(0xFFAFC4E8);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: itemColor, size: 27),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                color: itemColor,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
