import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_tracking_detail_screen.dart';

class AdminTrackingListScreen extends StatelessWidget {
  const AdminTrackingListScreen({super.key});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1B1B1B);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _borderBlue = Color(0xFFC9D9ED);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

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
                          Text(
                            'Tracking',
                            style: GoogleFonts.getFont(
                              'ADLaM Display',
                              color: _titleBlue,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Pantau order yang sedang dikirim.',
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTrackingList(admin),
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 3),
    );
  }

  Widget _buildTrackingList(AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessageCard(
            icon: Icons.error_outline_rounded,
            text: 'Gagal memuat data tracking.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(36),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders =
            (snapshot.data?.docs ?? []).where((document) {
              final String status = document.data()['status']?.toString() ?? '';

              return status == 'accepted' ||
                  status == 'pickingUp' ||
                  status == 'delivering' ||
                  status == 'onDelivery';
            }).toList();

        if (orders.isEmpty) {
          return _buildMessageCard(
            icon: Icons.route_outlined,
            text: 'Tidak ada order aktif.',
          );
        }

        return Column(
          children: orders.map((document) {
            final Map<String, dynamic> data = document.data();

            final String itemName =
                data['item_description']?.toString().trim().isNotEmpty == true
                ? data['item_description'].toString().trim()
                : 'Paket';

            final String status = data['status']?.toString() ?? '';

            final String destinationAddress =
                (data['dest_address'] ?? data['destination_address'] ?? '-')
                    .toString();

            final String driverId = data['driver_id']?.toString() ?? '';

            final String shortId = document.id.length > 8
                ? document.id.substring(0, 8).toUpperCase()
                : document.id.toUpperCase();

            return _buildTrackingCard(
              context: context,
              orderId: document.id,
              shortId: shortId,
              itemName: itemName,
              status: admin.statusLabel(status),
              destinationAddress: destinationAddress,
              driverId: driverId,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTrackingCard({
    required BuildContext context,
    required String orderId,
    required String shortId,
    required String itemName,
    required String status,
    required String destinationAddress,
    required String driverId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminTrackingDetailScreen(orderId: orderId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _titleBlue.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: _primaryBlue,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '#ORD-$shortId',
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F0FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0066FF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFFF4A45),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destinationAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _textGrey,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      color: _titleBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        driverId.trim().isEmpty
                            ? 'Driver belum tersedia'
                            : 'Driver tersedia',
                        style: GoogleFonts.inter(
                          color: _textGrey,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    Text(
                      'View Detail',
                      style: GoogleFonts.inter(
                        color: _primaryBlue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _titleBlue,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 42),
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
