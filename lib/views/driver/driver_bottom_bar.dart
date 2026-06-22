import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const DriverBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _unselectedColor = Color(0xFFAFC4E8);

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
              _DriverBottomItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _DriverBottomItem(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _DriverBottomItem(
                icon: Icons.forum_outlined,
                label: 'Chat',
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _DriverBottomItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                selected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverBottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DriverBottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? Colors.white
        : DriverBottomBar._unselectedColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 27),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
