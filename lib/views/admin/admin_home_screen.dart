import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_order_list_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1D2530);
  static const Color _textGrey = Color(0xFF7D8793);
  static const Color _borderBlue = Color(0xFFC9D9ED);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  void _openOrders(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AdminOrdersScreen();
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
      (route) => false,
    );
  }

  String _todayText() {
    const List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final DateTime now = DateTime.now();

    return 'Today, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF20A66A);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFD75C68);

      case 'pending':
        return const Color(0xFFD99519);

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFF3478C7);

      default:
        return _textGrey;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFE1F8EB);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFFFE8EB);

      case 'pending':
        return const Color(0xFFFFF4D7);

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFFE7F1FF);

      default:
        return const Color(0xFFF0F2F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();
    final AdminViewModel admin = context.watch<AdminViewModel>();

    final String adminName = auth.currentUser?.name.trim().isNotEmpty == true
        ? auth.currentUser!.name.trim()
        : 'Admin';

    return Scaffold(
      backgroundColor: _pageBackground,
      extendBody: true,
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
            bottom: false,
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(23, 35, 23, 120),
                        children: [
                          _buildHeader(adminName),
                          const SizedBox(height: 68),
                          _buildOverviewHeader(),
                          const SizedBox(height: 22),
                          _buildOverviewGrid(context, admin),
                          const SizedBox(height: 42),
                          _buildRecentHeader(context),
                          const SizedBox(height: 16),
                          _buildRecentOrders(context, admin),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 0),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK!',
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.getFont(
                  'ADLaM Display',
                  color: _primaryBlue,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFFDCEEFF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC4DAF0)),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: _primaryBlue,
            size: 36,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Overview',
            style: GoogleFonts.inter(
              color: _primaryBlue,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF8A929B)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 19,
                color: _textGrey,
              ),
              const SizedBox(width: 8),
              Text(
                _todayText(),
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewGrid(BuildContext context, AdminViewModel admin) {
    if (admin.isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: [
        _DashboardCard(
          title: 'Total\nOrders',
          value: admin.totalOrders,
          icon: Icons.inventory_2_outlined,
          backgroundColor: const Color(0xFFAEDAFF),
          iconBackgroundColor: const Color(0xFF6CA9D7),
          borderColor: const Color(0xFF4676A3),
          onTap: () {
            _openOrders(context);
          },
        ),
        _DashboardCard(
          title: 'Active\nDrivers',
          value: admin.activeDrivers,
          icon: Icons.delivery_dining_rounded,
          backgroundColor: const Color(0xFFD1F5DC),
          iconBackgroundColor: const Color(0xFF0B9DA3),
          borderColor: const Color(0xFF467D85),
        ),
        _DashboardCard(
          title: 'Ongoing\nOrders',
          value: admin.ongoingOrders,
          icon: Icons.access_time_rounded,
          backgroundColor: const Color(0xFFFFFAC7),
          iconBackgroundColor: const Color(0xFFE3E58B),
          borderColor: const Color(0xFF607B89),
          onTap: () {
            _openOrders(context);
          },
        ),
        _DashboardCard(
          title: 'Completed\nOrders',
          value: admin.completedOrders,
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFFD8D0FF),
          iconBackgroundColor: const Color(0xFF9B82EB),
          borderColor: const Color(0xFF5A6990),
          onTap: () {
            _openOrders(context);
          },
        ),
      ],
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recent Activity',
            style: GoogleFonts.inter(
              color: _primaryBlue,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            _openOrders(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'See All',
              style: GoogleFonts.inter(
                color: _titleBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context, AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessageCard(
            icon: Icons.error_outline_rounded,
            text: 'Gagal memuat aktivitas.',
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
            snapshot.data!.docs.take(4).toList();

        if (documents.isEmpty) {
          return _buildMessageCard(
            icon: Icons.inventory_2_outlined,
            text: 'Belum ada aktivitas order.',
          );
        }

        return Column(
          children: documents.map((document) {
            final Map<String, dynamic> data = document.data();

            final String item =
                data['item_description']?.toString().trim() ?? '';

            final String status = data['status']?.toString().trim() ?? '';

            final String shortId = document.id.length > 8
                ? document.id.substring(0, 8).toUpperCase()
                : document.id.toUpperCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderBlue),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  _openOrders(context);
                },
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: _primaryBlue,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#ORD-$shortId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.isEmpty ? 'Paket' : item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBackgroundColor(status),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            admin.statusLabel(status),
                            style: GoogleFonts.inter(
                              color: _statusTextColor(status),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          admin.formatTime(data['created_at']),
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMessageCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 40),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 74,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF21456F),
                        fontSize: 12,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.toString(),
                      style: GoogleFonts.inter(
                        color: iconBackgroundColor,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF5D7794),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
