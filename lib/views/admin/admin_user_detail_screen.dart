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

  static const Color _textDark = Color(0xFF1B1B1B);

  static const Color _textGrey = Color(0xFF687386);

  static const Color _borderBlue = Color(0xFFC9D9ED);

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: _primaryBlue,
                        ),
                      ),
                      const Spacer(),
                      SvgPicture.asset(AppAssets.logo, width: 175),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
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

                              final String photoUrl =
                                  (data['photo_url'] ?? data['photoUrl'] ?? '')
                                      .toString();

                              final bool isOnline =
                                  data['is_online'] == true ||
                                  data['isOnline'] == true;

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  30,
                                  24,
                                  45,
                                ),
                                children: [
                                  Text(
                                    'User Detail',
                                    style: GoogleFonts.getFont(
                                      'ADLaM Display',
                                      color: _titleBlue,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Informasi lengkap akun DeltaSend.',
                                    style: GoogleFonts.inter(
                                      color: _textGrey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: _borderBlue),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 96,
                                          height: 96,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: _titleBlue.withValues(
                                              alpha: 0.15,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: photoUrl.trim().isEmpty
                                              ? const Icon(
                                                  Icons.person_rounded,
                                                  size: 54,
                                                  color: _primaryBlue,
                                                )
                                              : Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return const Icon(
                                                          Icons.person_rounded,
                                                          size: 54,
                                                          color: _primaryBlue,
                                                        );
                                                      },
                                                ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            color: _textDark,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          email,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            color: _textGrey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 25),
                                        _DetailRow(
                                          icon: Icons.badge_outlined,
                                          label: 'Role',
                                          value: role,
                                        ),
                                        const Divider(
                                          height: 28,
                                          color: Color(0xFFE4E9F0),
                                        ),
                                        _DetailRow(
                                          icon: Icons.phone_outlined,
                                          label: 'Phone',
                                          value: phone,
                                        ),
                                        const Divider(
                                          height: 28,
                                          color: Color(0xFFE4E9F0),
                                        ),
                                        _DetailRow(
                                          icon: Icons.email_outlined,
                                          label: 'Email',
                                          value: email,
                                        ),
                                        if (role.toLowerCase() == 'driver') ...[
                                          const Divider(
                                            height: 28,
                                            color: Color(0xFFE4E9F0),
                                          ),
                                          _DetailRow(
                                            icon: Icons.circle_rounded,
                                            label: 'Driver Status',
                                            value: isOnline
                                                ? 'Online'
                                                : 'Offline',
                                            valueColor: isOnline
                                                ? const Color(0xFF0AAA55)
                                                : _textGrey,
                                          ),
                                        ],
                                      ],
                                    ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF608BC0), size: 23),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF687386),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: valueColor ?? const Color(0xFF1B1B1B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
