import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_live_tracking_screen.dart';
import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminTrackingDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminTrackingDetailScreen({
    super.key,
    required this.orderId,
  });

  String _formatDistance(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return '${number.toStringAsFixed(0)}KM';
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
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 96),
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
                child: StreamBuilder(
                  stream: admin.watchOrderDetail(orderId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text('Tracking tidak ditemukan'));
                    }

                    final data = snapshot.data!.data()!;

                    final status = data['status']?.toString() ?? '-';
                    final item = data['item_description']?.toString() ?? '-';
                    final driverId = data['driver_id']?.toString() ?? '';
                    final distance = _formatDistance(data['distance_km']);
                    final time = admin.formatTime(data['created_at']);

                    return Column(
                      children: [
                        _header(context),
                        const SizedBox(height: 22),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _mainCard(
                              context: context,
                              admin: admin,
                              orderId: orderId,
                              status: admin.statusLabel(status),
                              item: item,
                              time: time,
                              driverId: driverId,
                              distance: distance,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
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
            size: 26,
            color: Colors.black,
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Tracking Detail',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 26),
      ],
    );
  }

  Widget _mainCard({
    required BuildContext context,
    required AdminViewModel admin,
    required String orderId,
    required String status,
    required String item,
    required String time,
    required String driverId,
    required String distance,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _orderHeader(
            orderId: orderId,
            status: status,
          ),
          const SizedBox(height: 14),
          Text(
            item,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5F6770),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5F6770),
            ),
          ),
          const SizedBox(height: 10),
          _mapBox(),
          const SizedBox(height: 18),
          const Text(
            'Driver',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _driverInfo(
            context: context,
            admin: admin,
            driverId: driverId,
          ),
          const SizedBox(height: 24),
          _infoRow('Estimated Arrival', '12:45'),
          const SizedBox(height: 14),
          _infoRow('Distance Remaining', distance),
          const SizedBox(height: 26),
          const Text(
            'Delivery Status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _statusStep('Completed', true),
          const SizedBox(height: 10),
          _statusStep('On Delivery', true),
          const SizedBox(height: 10),
          _statusStep('Delivered', false),
        ],
      ),
    );
  }

  Widget _orderHeader({
    required String orderId,
    required String status,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '#$orderId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _statusChip(status),
      ],
    );
  }

  Widget _mapBox() {
    return Container(
      height: 224,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.loginBackground,
              fit: BoxFit.cover,
            ),
            CustomPaint(
              painter: _RoutePainter(),
            ),
            const Positioned(
              left: 36,
              bottom: 32,
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 34,
              ),
            ),
            const Positioned(
              right: 42,
              top: 22,
              child: Icon(
                Icons.location_on,
                color: Color(0xFF00A651),
                size: 32,
              ),
            ),
            const Positioned(
              left: 72,
              top: 82,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF00A651),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverInfo({
    required BuildContext context,
    required AdminViewModel admin,
    required String driverId,
  }) {
    if (driverId.isEmpty) {
      return const Text(
        'Belum ada driver',
        style: TextStyle(color: Color(0xFF5F6770)),
      );
    }

    return StreamBuilder(
      stream: admin.watchUserDetail(driverId),
      builder: (context, snapshot) {
        String name = '-';
        String phone = '-';
        String photoUrl = '';
        String rating = '-';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data()!;
          name = data['name']?.toString() ?? '-';
          phone = data['phone']?.toString() ?? '-';
          photoUrl = data['photo_url']?.toString() ?? '';
          rating = data['rating_avg']?.toString() ?? '-';
        }

        return Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFD6E7F8),
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5F6770),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              rating,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFB800),
              size: 22,
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5F6770),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _statusStep(String label, bool active) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD9FBE2) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF00A651) : const Color(0xFF9AA6B2),
            fontSize: 12,
          ),
        ),
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
            _BottomItem(icon: Icons.inventory_2_rounded, label: 'Orders'),
            _BottomItem(
              icon: Icons.route_rounded,
              label: 'Tracking',
              active: true,
            ),
            _BottomItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..lineTo(size.width * 0.21, size.height * 0.48)
      ..lineTo(size.width * 0.38, size.height * 0.40)
      ..lineTo(size.width * 0.48, size.height * 0.45)
      ..lineTo(size.width * 0.67, size.height * 0.34)
      ..lineTo(size.width * 0.82, size.height * 0.23);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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