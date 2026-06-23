import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminLiveTrackingScreen extends StatelessWidget {
  final String orderId;

  const AdminLiveTrackingScreen({
    super.key,
    required this.orderId,
  });

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
                      return const Center(
                        child: Text('Live tracking tidak ditemukan'),
                      );
                    }

                    final data = snapshot.data!.data()!;

                    final status = data['status']?.toString() ?? '-';
                    final item = data['item_description']?.toString() ?? '-';
                    final driverId = data['driver_id']?.toString() ?? '';

                    final distanceRemaining = admin.formatRemainingDistance(
                      driverLat: data['driver_lat'],
                      driverLng: data['driver_lng'],
                      destLat: data['dest_lat'],
                      destLng: data['dest_lng'],
                    );

                    return Column(
                      children: [
                        _header(context),
                        const SizedBox(height: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _mainCard(
                              context: context,
                              admin: admin,
                              orderId: orderId,
                              status: admin.statusLabel(status),
                              item: item,
                              driverId: driverId,
                              distanceRemaining: distanceRemaining,
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
              'Live Tracking',
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
    required String driverId,
    required String distanceRemaining,
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
          _mapBox(),
          const SizedBox(height: 14),
          Row(
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
          const SizedBox(height: 20),
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
          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  label: 'ETA',
                  value: '12:45',
                ),
              ),
              Expanded(
                child: _smallInfo(
                  label: 'Distance Remaining',
                  value: distanceRemaining,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapBox() {
    return Container(
      height: 400,
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
              painter: _LiveRoutePainter(),
            ),
            const Positioned(
              left: 145,
              bottom: 34,
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 38,
              ),
            ),
            const Positioned(
              left: 65,
              top: 22,
              child: Icon(
                Icons.location_on,
                color: Color(0xFF00A651),
                size: 38,
              ),
            ),
            const Positioned(
              left: 135,
              top: 230,
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
            Positioned(
              right: 12,
              top: 250,
              child: Container(
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    SizedBox(height: 10),
                    Icon(Icons.add, size: 22),
                    Divider(height: 18),
                    Icon(Icons.remove, size: 22),
                    SizedBox(height: 10),
                  ],
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

  Widget _smallInfo({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF5F6770),
          ),
        ),
        const SizedBox(height: 14),
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

class _LiveRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.88)
      ..lineTo(size.width * 0.36, size.height * 0.66)
      ..lineTo(size.width * 0.45, size.height * 0.48)
      ..lineTo(size.width * 0.35, size.height * 0.32)
      ..lineTo(size.width * 0.37, size.height * 0.16)
      ..lineTo(size.width * 0.22, size.height * 0.06);

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