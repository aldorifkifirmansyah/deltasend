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

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const Color _primaryBlue = Color(0xFF133D87);

  static const Color _titleBlue = Color(0xFF608BC0);

  static const Color _textDark = Color(0xFF1B1B1B);

  static const Color _textGrey = Color(0xFF687386);

  static const Color _borderBlue = Color(0xFFC9D9ED);

  static const Color _pageBackground = Color(0xFFF8FAFD);

  void _openOrders() {
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

    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();
    final AdminViewModel admin = context.watch<AdminViewModel>();

    final String adminName = auth.currentUser?.name.trim().isNotEmpty == true
        ? auth.currentUser!.name.trim()
        : 'Admin';

    return AnimatedBuilder(
      animation: admin,
      builder: (context, child) {
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
                    const SizedBox(height: 18),
                    SvgPicture.asset(AppAssets.logo, width: 215),
                    const SizedBox(height: 24),
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
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(22, 28, 22, 120),
                            children: [
                              _buildHeader(adminName),
                              const SizedBox(height: 28),
                              _buildOverviewHeader(),
                              const SizedBox(height: 18),
                              _buildOverviewGrid(admin),
                              const SizedBox(height: 30),
                              _buildRecentHeader(),
                              const SizedBox(height: 13),
                              _buildRecentOrders(admin),
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
      },
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
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.getFont(
                  'ADLaM Display',
                  color: _primaryBlue,
                  fontSize: 23,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 49,
          height: 49,
          decoration: BoxDecoration(
            color: _titleBlue.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: _primaryBlue,
            size: 29,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewHeader() {
    return Row(
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
            color: _primaryBlue,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4DCE6)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: _textGrey,
              ),
              const SizedBox(width: 6),
              Text(
                _todayText(),
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewGrid(AdminViewModel admin) {
    if (admin.isLoading) {
      return const SizedBox(
        height: 210,
        child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.42,
      children: [
        _DashboardCard(
          title: 'Total Orders',
          value: admin.totalOrders,
          icon: Icons.inventory_2_outlined,
          backgroundColor: const Color(0xFFE7F2FF),
          iconColor: const Color(0xFF397DB7),
          borderColor: const Color(0xFF9DC5E8),
          onTap: _openOrders,
        ),
        _DashboardCard(
          title: 'Active Drivers',
          value: admin.activeDrivers,
          icon: Icons.delivery_dining_rounded,
          backgroundColor: const Color(0xFFE8F8EE),
          iconColor: const Color(0xFF179A5B),
          borderColor: const Color(0xFFA9DFC2),
        ),
        _DashboardCard(
          title: 'Ongoing Orders',
          value: admin.ongoingOrders,
          icon: Icons.access_time_rounded,
          backgroundColor: const Color(0xFFFFF7DD),
          iconColor: const Color(0xFFC79516),
          borderColor: const Color(0xFFE9D58E),
          onTap: _openOrders,
        ),
        _DashboardCard(
          title: 'Completed',
          value: admin.completedOrders,
          icon: Icons.check_circle_outline_rounded,
          backgroundColor: const Color(0xFFF0EBFF),
          iconColor: const Color(0xFF7961C9),
          borderColor: const Color(0xFFC8BAEE),
          onTap: _openOrders,
        ),
      ],
    );
  }

  Widget _buildRecentHeader() {
    return Row(
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.inter(
            color: _primaryBlue,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _openOrders,
          child: Text(
            'See All',
            style: GoogleFonts.inter(
              color: _titleBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(AdminViewModel admin) {
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

        final documents = snapshot.data!.docs.take(4).toList();

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

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _borderBlue),
              ),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _titleBlue.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: _primaryBlue,
                  ),
                ),
                title: Text(
                  item.isEmpty ? 'Paket' : item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  admin.statusLabel(status),
                  style: GoogleFonts.inter(color: _textGrey, fontSize: 11.5),
                ),
                trailing: Text(
                  admin.formatTime(data['created_at']),
                  style: GoogleFonts.inter(color: _textGrey, fontSize: 11),
                ),
                onTap: _openOrders,
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
  final Color iconColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 54,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF334155),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value.toString(),
                      style: GoogleFonts.inter(
                        color: iconColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
