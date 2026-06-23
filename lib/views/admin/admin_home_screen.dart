import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../utils/app_assets.dart';

import 'admin_users_screen.dart';
import 'admin_order_list_screen.dart';
import 'admin_tracking_list_screen.dart';
import 'admin_profile_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasLoaded) {
      _hasLoaded = true;
      Future.microtask(() {
        context.read<AdminViewModel>().initAdminDashboard();
      });
    }
  }

  void _goTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final admin = context.watch<AdminViewModel>();
    final user = auth.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.loginBackground,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: admin.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(user?.name ?? 'Admin'),
                          const SizedBox(height: 86),
                          _overviewHeader(),
                          const SizedBox(height: 22),
                          _overviewGrid(admin),
                          const SizedBox(height: 38),
                          _recentActivityHeader(),
                          const SizedBox(height: 12),
                          _emptyActivity(),
                          _emptyActivity(),
                          _emptyActivity(),
                          _emptyActivity(),
                          const Spacer(),
                          _delayAlert(),
                          const SizedBox(height: 54),
                        ],
                      ),
              ),
            ),
          ),
          _bottomNav(),
        ],
      ),
    );
  }

  Widget _header(String name) {
    final displayName = name.trim().isNotEmpty ? name : 'Admin';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WELCOME BACK!',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF5F6770),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF133D87),
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFD8E6F3),
          child: Icon(
            Icons.person,
            color: Color(0xFF133D87),
          ),
        ),
      ],
    );
  }

  Widget _overviewHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF133D87),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF5F6770)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF5F6770),
              ),
              SizedBox(width: 6),
              Text(
                'Today, 30 April 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5F6770),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overviewGrid(AdminViewModel admin) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 22,
      mainAxisSpacing: 22,
      childAspectRatio: 1.73,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard(
          title: 'Total\nOrders',
          value: admin.totalOrders.toString(),
          icon: Icons.inventory_2_outlined,
          bgColor: const Color(0xFFBFE3FF),
          iconBg: const Color(0xFF78A8CC),
          borderColor: const Color(0xFF0066CC),
          valueColor: const Color(0xFF78A8CC),
        ),
        _statCard(
          title: 'Active\nDrivers',
          value: admin.activeDrivers.toString(),
          icon: Icons.delivery_dining,
          bgColor: const Color(0xFFD9FBE2),
          iconBg: const Color(0xFF078A9B),
          borderColor: const Color(0xFF0096A7),
          valueColor: const Color(0xFF78A8CC),
        ),
        _statCard(
          title: 'Ongoing\nOrders',
          value: admin.ongoingOrders.toString(),
          icon: Icons.access_time,
          bgColor: const Color(0xFFFFFDD0),
          iconBg: const Color(0xFFE8E5A8),
          borderColor: const Color(0xFF99925B),
          valueColor: const Color(0xFFB8B27A),
        ),
        _statCard(
          title: 'Completed\nOrders',
          value: admin.completedOrders.toString(),
          icon: Icons.check_circle,
          bgColor: const Color(0xFFE0D6FF),
          iconBg: const Color(0xFFA595E8),
          borderColor: const Color(0xFF6E54D9),
          valueColor: const Color(0xFF8B79D9),
        ),
      ],
    );
  }

  Widget _recentActivityHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF133D87),
          ),
        ),
        Text(
          'See All',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF608BC0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _delayAlert() {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F2),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_rounded,
              color: Color(0xFFFF4B55),
              size: 32,
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 orders are delayed',
                  style: TextStyle(
                    color: Color(0xFFFF4B55),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 82,
        decoration: const BoxDecoration(
          color: Color(0xFF133D87),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(100),
            topRight: Radius.circular(100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _BottomItem(
              icon: Icons.home_rounded,
              label: 'Dashboard',
              active: true,
            ),
            _BottomItem(
              icon: Icons.groups_rounded,
              label: 'Users',
              onTap: () => _goTo(AdminUsersScreen()),
            ),
            _BottomItem(
              icon: Icons.inventory_2_rounded,
              label: 'Orders',
              onTap: () => _goTo(AdminOrdersScreen()),
            ),
            _BottomItem(
              icon: Icons.route_rounded,
              label: 'Tracking',
              onTap: () => _goTo(AdminTrackingListScreen()),
            ),
            _BottomItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              onTap: () => _goTo(AdminProfileScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconBg,
    required Color borderColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 58,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    color: Color(0xFF133D87),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1,
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyActivity() {
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E7F8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white.withOpacity(0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}