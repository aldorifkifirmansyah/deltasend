import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

import 'admin_home_screen.dart';
import 'admin_users_screen.dart';
import 'admin_order_list_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_tracking_detail_screen.dart';

class AdminTrackingListScreen extends StatelessWidget {
  const AdminTrackingListScreen({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminViewModel>();

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
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 95),
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
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Spacer(),
                        Text(
                          'Tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.search, size: 28),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: admin.changeOrderSearchQuery,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: Color(0xFF9AA6B2),
                          ),
                          hintText: 'Search order...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9AA6B2),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _filterButton(admin, 'All', 'all'),
                        const SizedBox(width: 10),
                        _filterButton(admin, 'On Delivery', 'onDelivery'),
                        const SizedBox(width: 10),
                        _filterButton(admin, 'Completed', 'completed'),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: StreamBuilder(
                          stream: admin.watchOrders(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text('Belum ada tracking order'),
                              );
                            }

                            final orders = snapshot.data!.docs.where((doc) {
                              final data = doc.data();
                              final status = data['status']?.toString() ?? '';

                              return admin.isOrderMatchStatus(status) &&
                                  admin.isOrderMatchSearch(doc.id, data);
                            }).toList();

                            if (orders.isEmpty) {
                              return const Center(
                                child: Text('Tracking tidak ditemukan'),
                              );
                            }

                            return ListView.separated(
                              itemCount: orders.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 22,
                                color: Color(0xFFE5E7EB),
                              ),
                              itemBuilder: (context, index) {
                                final doc = orders[index];
                                final data = doc.data();

                                final status =
                                    data['status']?.toString() ?? '-';

                                final pickup =
                                    data['pickup_address']?.toString() ?? '-';

                                final destination =
                                    data['dest_address']?.toString() ??
                                        data['destination_address']
                                            ?.toString() ??
                                        '-';

                                final item =
                                    data['item_description']?.toString();

                                final description =
                                    item == null || item.isEmpty
                                        ? '$pickup\n$destination'
                                        : item;

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AdminTrackingDetailScreen(
                                          orderId: doc.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _trackingItem(
                                    orderId: doc.id,
                                    description: description,
                                    status: admin.statusLabel(status),
                                    time: admin.formatTime(data['created_at']),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _bottomNav(context),
        ],
      ),
    );
  }

  Widget _filterButton(
    AdminViewModel admin,
    String label,
    String value,
  ) {
    final isActive = admin.selectedOrderStatus == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => admin.changeOrderStatus(value),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEAF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF133D87)
                  : const Color(0xFFF0F0F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isActive
                  ? const Color(0xFF133D87)
                  : const Color(0xFF5F6770),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _trackingItem({
    required String orderId,
    required String description,
    required String status,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 118,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                AppAssets.loginBackground,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Color(0xFF5F6770),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0066FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6770),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 34,
            color: Color(0xFF9AA6B2),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
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
            _BottomItem(
              icon: Icons.home_rounded,
              label: 'Dashboard',
              onTap: () => _goTo(context, const AdminHomeScreen()),
            ),
            _BottomItem(
              icon: Icons.groups_rounded,
              label: 'Users',
              onTap: () => _goTo(context, const AdminUsersScreen()),
            ),
            _BottomItem(
              icon: Icons.inventory_2_rounded,
              label: 'Orders',
              onTap: () => _goTo(context, const AdminOrdersScreen()),
            ),
            const _BottomItem(
              icon: Icons.route_rounded,
              label: 'Tracking',
              active: true,
            ),
            _BottomItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              onTap: () => _goTo(context, AdminProfileScreen()),
            ),
          ],
        ),
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