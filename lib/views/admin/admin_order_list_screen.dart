import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

import 'admin_home_screen.dart';
import 'admin_users_screen.dart';
import 'admin_tracking_list_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

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
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.loginBackground,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                SvgPicture.asset(
                  AppAssets.logo,
                  width: 214,
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(22, 0, 22, 90),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Orders',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF608BC0),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFC5D8EE),
                            ),
                          ),
                          child: TextField(
                            onChanged: admin.changeOrderSearchQuery,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              icon: Icon(
                                Icons.search,
                                color: Color(0xFF608BC0),
                              ),
                              hintText: 'Search your order',
                              hintStyle: TextStyle(
                                color: Color(0xFF9AA6B2),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _filterButton(admin, 'All', 'all'),
                            const SizedBox(width: 10),
                            _filterButton(admin, 'On Delivery', 'onDelivery'),
                            const SizedBox(width: 10),
                            _filterButton(admin, 'Completed', 'completed'),
                            const SizedBox(width: 10),
                            _filterButton(admin, 'Cancel', 'cancelled'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
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
                                  child: Text('Belum ada order'),
                                );
                              }

                              final orders = snapshot.data!.docs.where((doc) {
                                final data = doc.data();
                                final status =
                                    data['status']?.toString() ?? '';

                                return admin.isOrderMatchStatus(status) &&
                                    admin.isOrderMatchSearch(doc.id, data);
                              }).toList();

                              if (orders.isEmpty) {
                                return const Center(
                                  child: Text('Order tidak ditemukan'),
                                );
                              }

                              return ListView.separated(
                                padding:
                                    const EdgeInsets.only(bottom: 24, top: 2),
                                itemCount: orders.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
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

                                  final itemDescription =
                                      data['item_description']?.toString();

                                  final description =
                                      itemDescription == null ||
                                              itemDescription.isEmpty
                                          ? '$pickup\n$destination'
                                          : itemDescription;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminOrderDetailScreen(
                                            orderId: doc.id,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: _orderCard(
                                      orderId: doc.id,
                                      description: description,
                                      status: admin.statusLabel(status),
                                      time: admin.formatTime(
                                        data['created_at'],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
        onTap: () {
          admin.changeOrderStatus(value);
        },
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF133D87) : const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFC5D8EE),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.white : const Color(0xFF6F7784),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard({
    required String orderId,
    required String description,
    required String status,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFC5D8EE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF133D87),
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '#${_shortOrderId(orderId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6F7784),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE3E8EF)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Color(0xFF608BC0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F7784),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6F7784),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Rp. -',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D23),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF608BC0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusChip(status),
        ],
      ),
    );
  }

  String _shortOrderId(String orderId) {
    final clean = orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final short = clean.length > 8 ? clean.substring(0, 8) : clean;
    return 'ORD-$short';
  }

  Widget _statusChip(String status) {
    final isCompleted = status.toLowerCase() == 'completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFD9FBE2)
            : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isCompleted
              ? const Color(0xFF00A651)
              : const Color(0xFF0066FF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
            const _BottomItem(
              icon: Icons.inventory_2_rounded,
              label: 'Orders',
              active: true,
            ),
            _BottomItem(
              icon: Icons.route_rounded,
              label: 'Tracking',
              onTap: () => _goTo(context, AdminTrackingListScreen()),
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