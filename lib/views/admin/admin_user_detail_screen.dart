import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  static const Color _primaryBlue = Color(0xFF133D87);

  static const Color _titleBlue = Color(0xFF608BC0);

  static const Color _textDark = Color(0xFF1A1D23);

  static const Color _textGrey = Color(0xFF687386);

  static const Color _borderColor = Color(0xFFE5E7EB);

  static const Color _pageBackground = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 1),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return const ColoredBox(color: _pageBackground);
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),

                SvgPicture.asset(AppAssets.logo, width: 214),

                const SizedBox(height: 24),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: admin.watchUserDetail(userId),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildError();
                              }

                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
                                );
                              }

                              if (!snapshot.data!.exists) {
                                return _buildNotFound();
                              }

                              final data = snapshot.data!.data()!;

                              final String role =
                                  data['role']?.toString().toLowerCase() ??
                                  'customer';

                              if (role == 'driver') {
                                return StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream: admin.watchDriverLocation(userId),
                                  builder: (context, locationSnapshot) {
                                    final locationData = locationSnapshot.data
                                        ?.data();

                                    return _buildContent(
                                      context: context,
                                      admin: admin,
                                      data: data,
                                      role: role,
                                      isOnline:
                                          locationData?['is_online'] == true,
                                      lastSeen:
                                          locationData?['updated_at'] ??
                                          locationData?['last_seen'],
                                    );
                                  },
                                );
                              }

                              return _buildContent(
                                context: context,
                                admin: admin,
                                data: data,
                                role: role,
                                isOnline: data['is_active'] != false,
                                lastSeen: data['updated_at'],
                              );
                            },
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AdminViewModel admin,
    required Map<String, dynamic> data,
    required String role,
    required bool isOnline,
    required dynamic lastSeen,
  }) {
    final String name = data['name']?.toString().trim() ?? '';

    final String email = data['email']?.toString().trim() ?? '';

    final String phone = data['phone']?.toString().trim() ?? '';

    final String photoUrl = data['photo_url']?.toString().trim() ?? '';

    final String address = data['address']?.toString().trim() ?? '';

    final String ratingAvg = admin.formatRating(data['rating_avg']);

    final String ratingCount = data['rating_count']?.toString() ?? '0';

    final String joinedDate = admin.formatDate(data['created_at']);

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
            children: [
              _buildProfileSection(
                name: name.isNotEmpty ? name : '-',
                email: email,
                phone: phone,
                role: role,
                joinedDate: joinedDate,
                photoUrl: photoUrl,
                isOnline: isOnline,
              ),
              const SizedBox(height: 24),
              _buildAccountInformation(
                name: name.isNotEmpty ? name : '-',
                email: email.isNotEmpty ? email : '-',
                phone: phone.isNotEmpty ? phone : '-',
                role: role,
                address: address.isNotEmpty ? address : '-',
                ratingAvg: ratingAvg,
                ratingCount: ratingCount,
                joinedDate: joinedDate,
                lastActive: _formatLastSeen(lastSeen, isOnline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textDark,
              size: 23,
            ),
          ),
          Expanded(
            child: Text(
              'User Detail',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileSection({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String joinedDate,
    required String photoUrl,
    required bool isOnline,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 78,
          height: 78,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFD6E7F8),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC5D8EE)),
          ),
          child: photoUrl.isEmpty
              ? const Icon(Icons.person_rounded, color: _primaryBlue, size: 44)
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.person_rounded,
                      color: _primaryBlue,
                      size: 44,
                    );
                  },
                ),
        ),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildStatusChip(isOnline),
                ],
              ),
              const SizedBox(height: 7),
              _buildRoleChip(role),
              const SizedBox(height: 11),
              Text(
                email.isNotEmpty ? email : '-',
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13.5),
              ),
              const SizedBox(height: 7),
              Text(
                phone.isNotEmpty ? phone : '-',
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13.5),
              ),
              const SizedBox(height: 7),
              Text(
                'Bergabung sejak $joinedDate',
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFE2F9EB) : const Color(0xFFFFF0D8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        isOnline ? 'Active' : 'Offline',
        style: GoogleFonts.inter(
          color: isOnline ? const Color(0xFF0AAA55) : const Color(0xFFE08B00),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final String label = role == 'driver' ? 'Driver' : 'Customer';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF0066FF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAccountInformation({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String address,
    required String ratingAvg,
    required String ratingCount,
    required String joinedDate,
    required String lastActive,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Akun',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 19),
          _buildInfoRow('Nama', name),
          _buildInfoRow('Email', email),
          _buildInfoRow('Nomor Telepon', phone),
          _buildInfoRow('Role', role == 'driver' ? 'Driver' : 'Customer'),
          _buildInfoRow('Alamat', address),
          _buildInfoRow('Status Terakhir', lastActive),
          if (role == 'driver') ...[
            _buildInfoRow('Rating Rata-rata', ratingAvg),
            _buildInfoRow('Jumlah Rating', ratingCount),
          ],
          _buildInfoRow('Tanggal Bergabung', joinedDate),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 19),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: _textGrey,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(dynamic value, bool isOnline) {
    if (isOnline) return 'Online';

    if (value is! Timestamp) {
      return 'Offline';
    }

    final Duration difference = DateTime.now().difference(value.toDate());

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    }

    return '${difference.inDays} hari lalu';
  }

  Widget _buildError() {
    return Center(
      child: Text(
        'Gagal memuat detail user.',
        style: GoogleFonts.inter(color: const Color(0xFFD14343), fontSize: 14),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Text(
        'User tidak ditemukan.',
        style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
      ),
    );
  }
}
