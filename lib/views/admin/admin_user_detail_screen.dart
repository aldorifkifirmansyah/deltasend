import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final String uid;

  const AdminUserDetailScreen({super.key, required this.uid});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF202832);
  static const Color _textGrey = Color(0xFF8A929C);
  static const Color _borderColor = Color(0xFFE0E5EB);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.read<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: _pageBackground);
            },
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 17),
                SvgPicture.asset(AppAssets.logo, width: 218),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: admin.watchUserDetail(uid),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildMessage(
                                  icon: Icons.error_outline_rounded,
                                  text: 'Gagal memuat detail user.',
                                );
                              }

                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
                                );
                              }

                              if (snapshot.data?.exists != true) {
                                return _buildMessage(
                                  icon: Icons.person_off_outlined,
                                  text: 'User tidak ditemukan.',
                                );
                              }

                              final Map<String, dynamic> data =
                                  snapshot.data!.data() ?? {};

                              final String name =
                                  data['name']?.toString().trim().isNotEmpty ==
                                      true
                                  ? data['name'].toString().trim()
                                  : 'Tanpa nama';

                              final String email =
                                  data['email']?.toString() ?? '-';

                              final String role =
                                  data['role']?.toString() ?? '-';

                              final String phone =
                                  (data['phone'] ?? data['phone_number'] ?? '-')
                                      .toString();

                              final String address =
                                  (data['address'] ?? data['alamat'] ?? '-')
                                      .toString();

                              final String photoUrl =
                                  (data['photo_url'] ?? data['photoUrl'] ?? '')
                                      .toString();

                              final bool isOnline =
                                  data['is_online'] == true ||
                                  data['isOnline'] == true;

                              // FIELD RATING YANG DIDUKUNG
                              final dynamic ratingValue =
                                  data['rating_avg'] ??
                                  data['ratingAvg'] ??
                                  data['rating_average'] ??
                                  data['average_rating'] ??
                                  data['rating'] ??
                                  0;

                              // FIELD JUMLAH RATING YANG DIDUKUNG
                              final dynamic ratingCountValue =
                                  data['rating_count'] ??
                                  data['ratingCount'] ??
                                  data['total_rating'] ??
                                  data['jumlah_rating'] ??
                                  0;

                              final String averageRating = _formatRating(
                                ratingValue,
                              );

                              final String ratingCount = _formatRatingCount(
                                ratingCountValue,
                              );

                              final String joinedDate = _formatJoinedDate(
                                data['created_at'] ??
                                    data['createdAt'] ??
                                    data['joined_at'] ??
                                    data['joinedAt'],
                              );

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  42,
                                ),
                                children: [
                                  _buildTopHeader(context),
                                  const SizedBox(height: 30),
                                  _buildProfileHeader(
                                    name: name,
                                    email: email,
                                    phone: phone,
                                    role: role,
                                    photoUrl: photoUrl,
                                    isOnline: isOnline,
                                    joinedDate: joinedDate,
                                  ),
                                  const SizedBox(height: 32),
                                  _buildAccountInformation(
                                    name: name,
                                    email: email,
                                    phone: phone,
                                    role: role,
                                    address: address,
                                    isOnline: isOnline,
                                    averageRating: averageRating,
                                    ratingCount: ratingCount,
                                    joinedDate: joinedDate,
                                  ),
                                ],
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

  Widget _buildTopHeader(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF111820),
                size: 26,
              ),
            ),
          ),
          Center(
            child: Text(
              'User Detail',
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String photoUrl,
    required bool isOnline,
    required String joinedDate,
  }) {
    final bool isDriver = role.trim().toLowerCase() == 'driver';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 104,
          height: 104,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFDCEEFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC8DCEF)),
          ),
          child: photoUrl.trim().isEmpty
              ? const Icon(Icons.person_rounded, size: 58, color: _primaryBlue)
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person_rounded,
                      size: 58,
                      color: _primaryBlue,
                    );
                  },
                ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isDriver)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFFE1F8EB)
                            : const Color(0xFFFFF2D7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        isOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.inter(
                          color: isOnline
                              ? const Color(0xFF22A86C)
                              : const Color(0xFFD69A22),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _capitalize(role),
                  style: GoogleFonts.inter(
                    color: _titleBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                'Bergabung sejak $joinedDate',
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInformation({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String address,
    required bool isOnline,
    required String averageRating,
    required String ratingCount,
    required String joinedDate,
  }) {
    final bool isDriver = role.trim().toLowerCase() == 'driver';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Akun',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 25),
          _InformationRow(label: 'Nama', value: name),
          _InformationRow(label: 'Email', value: email),
          _InformationRow(label: 'Nomor Telepon', value: phone),
          _InformationRow(label: 'Role', value: _capitalize(role)),
          _InformationRow(label: 'Alamat', value: address),
          if (isDriver) ...[
            _InformationRow(
              label: 'Status Terakhir',
              value: isOnline ? 'Online' : 'Offline',
              valueColor: isOnline
                  ? const Color(0xFF22A86C)
                  : const Color(0xFFD69A22),
            ),
            _InformationRow(
              label: 'Rating Rata-rata',
              value: averageRating,
              valueColor: averageRating == '-'
                  ? _textGrey
                  : const Color(0xFFFFA800),
            ),
            _InformationRow(label: 'Jumlah Rating', value: ratingCount),
          ],
          _InformationRow(
            label: 'Tanggal Bergabung',
            value: joinedDate,
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }

  String _formatJoinedDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return '-';
    }

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final String day = date.day.toString().padLeft(2, '0');

    return '$day ${months[date.month - 1]} ${date.year}';
  }

  String _formatRating(dynamic value) {
    final double rating = double.tryParse(value?.toString() ?? '') ?? 0.0;

    if (rating <= 0) {
      return '-';
    }

    return rating.toStringAsFixed(1);
  }

  String _formatRatingCount(dynamic value) {
    final int count = int.tryParse(value?.toString() ?? '') ?? 0;

    return count.toString();
  }

  String _capitalize(String value) {
    final String clean = value.trim();

    if (clean.isEmpty) {
      return '-';
    }

    return '${clean[0].toUpperCase()}'
        '${clean.substring(1).toLowerCase()}';
  }

  Widget _buildMessage({required IconData icon, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _titleBlue, size: 48),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double bottomPadding;

  const _InformationRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bottomPadding = 21,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8A929C),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: valueColor ?? const Color(0xFF6F7781),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
