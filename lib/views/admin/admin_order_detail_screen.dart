import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminOrderDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  String _formatDistance(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return '${number.toStringAsFixed(2)} km';
  }

  String _formatCurrency(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    final raw = number.round().toString();

    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'Rp. $buffer';
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
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                    child: StreamBuilder(
                      stream: admin.watchOrderDetail(orderId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(
                            child: Text('Order tidak ditemukan'),
                          );
                        }

                        final data = snapshot.data!.data()!;

                        final status = data['status']?.toString() ?? '-';
                        final createdAt = data['created_at'];
                        final customerId =
                            data['customer_id']?.toString() ?? '';
                        final driverId = data['driver_id']?.toString() ?? '';
                        final pickupAddress =
                            data['pickup_address']?.toString() ?? '-';
                        final destinationAddress =
                            data['dest_address']?.toString() ??
                                data['destination_address']?.toString() ??
                                '-';
                        final itemDescription =
                            data['item_description']?.toString() ?? '-';
                        final weight =
                            data['weight_category_name']?.toString() ??
                                data['weightCategoryName']?.toString() ??
                                '-';

                        final distanceKm =
                            _formatDistance(data['distance_km']);
                        final totalCost =
                            _formatCurrency(data['total_cost']);

                        return Column(
                          children: [
                            _header(context),
                            const SizedBox(height: 20),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _orderHeaderCard(
                                      orderId: orderId,
                                      status: admin.statusLabel(status),
                                      date: admin.formatDate(createdAt),
                                      time: admin.formatTime(createdAt),
                                    ),
                                    const SizedBox(height: 16),
                                    _userCard(
                                      context: context,
                                      title: 'Customer',
                                      userId: customerId,
                                    ),
                                    const SizedBox(height: 16),
                                    _addressCard(
                                      pickupAddress: pickupAddress,
                                      destinationAddress: destinationAddress,
                                    ),
                                    const SizedBox(height: 16),
                                    _userCard(
                                      context: context,
                                      title: 'Driver',
                                      userId: driverId,
                                    ),
                                    const SizedBox(height: 16),
                                    _itemInfoCard(
                                      itemDescription: itemDescription,
                                      weight: weight,
                                      distanceKm: distanceKm,
                                    ),
                                    const SizedBox(height: 16),
                                    _paymentCard(totalCost: totalCost),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          _bottomNav(),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 24,
            color: Colors.black,
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Order Detail',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _orderHeaderCard({
    required String orderId,
    required String status,
    required String date,
    required String time,
  }) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$orderId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF6F7784),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusChip(status),
              const SizedBox(height: 8),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF6F7784),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _userCard({
    required BuildContext context,
    required String title,
    required String userId,
  }) {
    final admin = context.watch<AdminViewModel>();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          const SizedBox(height: 14),
          if (userId.isEmpty)
            const Text(
              'Belum ada data',
              style: TextStyle(color: Color(0xFF6F7784), fontSize: 12),
            )
          else
            StreamBuilder(
              stream: admin.watchUserDetail(userId),
              builder: (context, snapshot) {
                String name = '-';
                String phone = '-';
                String photoUrl = '';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data()!;
                  name = userData['name']?.toString() ?? '-';
                  phone = userData['phone']?.toString() ?? '-';
                  photoUrl = userData['photo_url']?.toString() ?? '';
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFD6E7F8),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF133D87),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: const TextStyle(
                              color: Color(0xFF6F7784),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF133D87),
                      size: 25,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _addressCard({
    required String pickupAddress,
    required String destinationAddress,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Pickup & Pengantaran'),
          const Divider(height: 24, color: Color(0xFFE3E8EF)),
          _addressRow(
            title: 'Pickup',
            address: pickupAddress,
            color: const Color(0xFF0066FF),
            icon: Icons.radio_button_checked_rounded,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 22,
                child: VerticalDivider(
                  width: 2,
                  thickness: 1.5,
                  color: Color(0xFFCAD4E1),
                ),
              ),
            ),
          ),
          _addressRow(
            title: 'Tujuan',
            address: destinationAddress,
            color: Color(0xFF0AAA55),
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _itemInfoCard({
    required String itemDescription,
    required String weight,
    required String distanceKm,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Item Information'),
          const Divider(height: 24, color: Color(0xFFE3E8EF)),
          _detailRow('Item', itemDescription),
          const SizedBox(height: 11),
          _detailRow('Weight', weight),
          const SizedBox(height: 11),
          _detailRow('Distance', distanceKm),
        ],
      ),
    );
  }

  Widget _paymentCard({
    required String totalCost,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Payment Details'),
          const Divider(height: 24, color: Color(0xFFE3E8EF)),
          _detailRow('Payment Method', 'Cash'),
          const SizedBox(height: 11),
          _detailRow('Delivery Fee', totalCost),
          const Divider(height: 24, color: Color(0xFFE3E8EF)),
          _detailRow('Total Payment', totalCost, bold: true),
        ],
      ),
    );
  }

  Widget _addressRow({
    required String title,
    required String address,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  color: Color(0xFF6F7784),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6F7784),
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: const Color(0xFF1A1D23),
              fontSize: bold ? 14 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1A1D23),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF0066FF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFC5D8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomItem(icon: Icons.home_rounded, label: 'Dashboard'),
            _BottomItem(icon: Icons.groups_rounded, label: 'Users'),
            _BottomItem(
              icon: Icons.inventory_2_rounded,
              label: 'Orders',
              active: true,
            ),
            _BottomItem(icon: Icons.route_rounded, label: 'Tracking'),
            _BottomItem(icon: Icons.person_rounded, label: 'Profile'),
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

  const _BottomItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white.withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
    );
  }
}