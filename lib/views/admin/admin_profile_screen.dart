import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../auth/login_screen.dart';
import 'admin_bottom_bar.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF171717);
  static const Color _textGrey = Color(0xFF697386);
  static const Color _borderBlue = Color(0xFFC7DCEC);
  static const Color _pageBackground = Color(0xFFF7F9FC);
  static const Color _logoutRed = Color(0xFFD83A47);

  bool _isLoggingOut = false;

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<void> _showLogoutConfirmation() async {
    if (_isLoggingOut) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _logoutRed.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _logoutRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keluar dari akun?',
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Kamu harus login kembali untuk mengakses halaman admin DeltaSend.',
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              style: TextButton.styleFrom(
                foregroundColor: _textGrey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
              ),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _logoutRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Sign Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await context.read<AuthViewModel>().signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout gagal: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 4),
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
                const SizedBox(height: 18),
                SvgPicture.asset(AppAssets.logo, width: 220),
                const SizedBox(height: 28),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.11),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _currentUserId.isEmpty
                        ? _buildMessage('Akun admin tidak ditemukan.')
                        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: admin.watchUserDetail(_currentUserId),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildMessage(
                                  'Gagal memuat profil admin.',
                                );
                              }

                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
                                );
                              }

                              if (!snapshot.data!.exists) {
                                return _buildMessage(
                                  'Data profil admin tidak ditemukan.',
                                );
                              }

                              final Map<String, dynamic> data = snapshot.data!
                                  .data()!;

                              return _buildProfileContent(data);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoggingOut)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.24),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _primaryBlue),
                      SizedBox(height: 14),
                      Text('Keluar dari akun...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> data) {
    final String name = data['name']?.toString().trim() ?? '';

    final String email = data['email']?.toString().trim() ?? '';

    final String role = data['role']?.toString().trim() ?? 'admin';

    final String photoUrl =
        (data['photo_url'] ?? data['photoUrl'])?.toString().trim() ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 34),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.getFont(
                      'ADLaM Display',
                      color: _titleBlue,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola informasi akun DeltaSend.',
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  _buildProfileCard(
                    name: name.isNotEmpty ? name : 'Admin',
                    email: email.isNotEmpty ? email : '-',
                    role: role,
                    photoUrl: photoUrl,
                  ),
                  const Spacer(),
                  const SizedBox(height: 72),
                  _buildSignOutButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard({
    required String name,
    required String email,
    required String role,
    required String photoUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 31, 24, 27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderBlue, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProfilePhoto(photoUrl),
          const SizedBox(height: 20),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            email,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 13.5),
          ),
          const SizedBox(height: 32),
          _buildInformationRow(
            icon: Icons.person_outline_rounded,
            label: 'Role',
            value: _formatRole(role),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _buildInformationRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email,
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto(String photoUrl) {
    return Container(
      width: 104,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1FC),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD8E7F6)),
      ),
      child: photoUrl.isEmpty
          ? const Icon(Icons.person_rounded, color: _primaryBlue, size: 58)
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const Center(
                  child: CircularProgressIndicator(
                    color: _primaryBlue,
                    strokeWidth: 2,
                  ),
                );
              },
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.person_rounded,
                  color: _primaryBlue,
                  size: 58,
                );
              },
            ),
    );
  }

  Widget _buildInformationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 42, child: Icon(icon, color: _titleBlue, size: 29)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _showLogoutConfirmation,
        style: OutlinedButton.styleFrom(
          foregroundColor: _logoutRed,
          backgroundColor: Colors.white,
          disabledForegroundColor: _logoutRed.withValues(alpha: 0.45),
          side: const BorderSide(color: _logoutRed, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 25),
        label: Text(
          _isLoggingOut ? 'SIGNING OUT...' : 'SIGN OUT',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    final String normalized = role.trim().toLowerCase();

    if (normalized.isEmpty) {
      return 'Admin';
    }

    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, color: _titleBlue, size: 50),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
