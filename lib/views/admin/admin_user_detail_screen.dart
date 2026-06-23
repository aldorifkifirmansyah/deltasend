import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final String userId;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

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
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
                      stream: admin.watchUserDetail(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(
                            child: Text('User tidak ditemukan'),
                          );
                        }

                        final data = snapshot.data!.data()!;

                        final name = data['name']?.toString() ?? '-';
                        final email = data['email']?.toString() ?? '-';
                        final phone = data['phone']?.toString() ?? '-';
                        final role = data['role']?.toString() ?? '-';
                        final ratingAvg =
                            data['rating_avg']?.toString() ?? '-';
                        final ratingCount =
                            data['rating_count']?.toString() ?? '-';
                        final photoUrl =
                            data['photo_url']?.toString() ?? '';
                        final joinedDate =
                            admin.formatDate(data['created_at']);

                        return Column(
                          children: [
                            _header(context),
                            const SizedBox(height: 36),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _profileSection(
                                      name: name,
                                      email: email,
                                      phone: phone,
                                      role: role,
                                      joinedDate: joinedDate,
                                      photoUrl: photoUrl,
                                    ),
                                    const SizedBox(height: 24),
                                    _accountInfoCard(
                                      name: name,
                                      email: email,
                                      phone: phone,
                                      role: role,
                                      ratingAvg: ratingAvg,
                                      ratingCount: ratingCount,
                                      joinedDate: joinedDate,
                                    ),
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
            size: 26,
            color: Colors.black,
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'User Detail',
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

  Widget _profileSection({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String joinedDate,
    required String photoUrl,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: const Color(0xFFD6E7F8),
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? const Icon(
                  Icons.person,
                  size: 42,
                  color: Color(0xFF133D87),
                )
              : null,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9FBE2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00A651),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0066FF),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5F6770),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phone.isEmpty ? '-' : phone,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5F6770),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bergabung sejak $joinedDate',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5F6770),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountInfoCard({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String ratingAvg,
    required String ratingCount,
    required String joinedDate,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Akun',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _infoRow('Nama', name),
          _infoRow('Email', email),
          _infoRow('Nomor Telepon', phone.isEmpty ? '-' : phone),
          _infoRow('Role', role),
          _infoRow('Rating Rata-rata', ratingAvg),
          _infoRow('Jumlah Rating', ratingCount),
          _infoRow('Tanggal Bergabung', joinedDate),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5F6770),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5F6770),
              ),
            ),
          ),
        ],
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
            _BottomItem(
              icon: Icons.groups_rounded,
              label: 'Users',
              active: true,
            ),
            _BottomItem(icon: Icons.inventory_2_rounded, label: 'Orders'),
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