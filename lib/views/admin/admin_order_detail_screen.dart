import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_user_detail_screen.dart';

class AdminOrderDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _pageBackground = Color(0xFFF7F9FC);
  static const Color _successGreen = Color(0xFF0AAA55);

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 2),
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
                    padding: const EdgeInsets.symmetric(horizontal: 22),
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
                            stream: admin.watchOrderDetail(orderId),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildMessage(
                                  icon: Icons.error_outline_rounded,
                                  text: 'Gagal memuat detail order.',
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
                                  icon: Icons.receipt_long_outlined,
                                  text: 'Order tidak ditemukan.',
                                );
                              }

                              final Map<String, dynamic> data = snapshot.data!
                                  .data()!;

                              return _buildContent(
                                context: context,
                                admin: admin,
                                data: data,
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
  }) {
    final String status = data['status']?.toString() ?? 'pending';

    final dynamic createdAt = data['created_at'];

    final dynamic updatedAt = data['updated_at'];

    final String customerId = data['customer_id']?.toString().trim() ?? '';

    final String driverId = data['driver_id']?.toString().trim() ?? '';

    final String pickupAddress =
        data['pickup_address']?.toString().trim() ?? '-';

    final String destinationAddress =
        (data['dest_address'] ?? data['destination_address'])
            ?.toString()
            .trim() ??
        '-';

    final String itemDescription =
        data['item_description']?.toString().trim() ?? '-';

    final String weight =
        (data['weight_category_name'] ??
                data['weightCategoryName'] ??
                data['weight_category'])
            ?.toString()
            .trim() ??
        '-';

    final dynamic distanceKm = data['distance_km'];

    final dynamic totalCost = data['total_cost'];

    final String proofPhotoUrl =
        (data['proof_photo_url'] ?? data['proofPhotoUrl'])?.toString().trim() ??
        '';

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 34),
            children: [
              _buildOrderHeaderCard(
                admin: admin,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
              const SizedBox(height: 15),
              _buildUserCard(
                context: context,
                admin: admin,
                title: 'Customer',
                userId: customerId,
                emptyText: 'Data customer tidak tersedia',
              ),
              const SizedBox(height: 15),
              _buildAddressCard(
                pickupAddress: pickupAddress,
                destinationAddress: destinationAddress,
                pickupTime: admin.formatTime(createdAt),
              ),
              const SizedBox(height: 15),
              _buildUserCard(
                context: context,
                admin: admin,
                title: 'Driver',
                userId: driverId,
                emptyText: 'Driver belum menerima order',
              ),
              const SizedBox(height: 15),
              _buildOrderInformationCard(
                admin: admin,
                itemDescription: itemDescription,
                weight: weight,
                distanceKm: distanceKm,
                totalCost: totalCost,
              ),
              if (proofPhotoUrl.isNotEmpty) ...[
                const SizedBox(height: 15),
                _buildProofPhotoCard(proofPhotoUrl),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 16, 3),
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
              'Order Detail',
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

  Widget _buildOrderHeaderCard({
    required AdminViewModel admin,
    required String status,
    required dynamic createdAt,
    required dynamic updatedAt,
  }) {
    final Color statusColor = _statusColor(status);

    final Color statusBackground = _statusBackground(status);

    return _sectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatOrderId(orderId),
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  admin.formatDate(createdAt),
                  style: GoogleFonts.inter(color: _textGrey, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  admin.statusLabel(status),
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                admin.formatTime(updatedAt ?? createdAt),
                style: GoogleFonts.inter(color: _textGrey, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required BuildContext context,
    required AdminViewModel admin,
    required String title,
    required String userId,
    required String emptyText,
  }) {
    if (userId.isEmpty) {
      return _sectionCard(
        title: title,
        child: Row(
          children: [
            const Icon(Icons.person_off_outlined, color: _textGrey, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                emptyText,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: admin.watchUserDetail(userId),
      builder: (context, snapshot) {
        final Map<String, dynamic>? data = snapshot.data?.data();

        final String name = data?['name']?.toString().trim() ?? '';

        final String phone = data?['phone']?.toString().trim() ?? '';

        final String email = data?['email']?.toString().trim() ?? '';

        final String photoUrl = data?['photo_url']?.toString().trim() ?? '';

        return _sectionCard(
          title: title,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFFD6E7F8),
                  shape: BoxShape.circle,
                ),
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: _primaryBlue,
                        size: 30,
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.person_rounded,
                            color: _primaryBlue,
                            size: 30,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      phone.isNotEmpty
                          ? phone
                          : email.isNotEmpty
                          ? email
                          : '-',
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
              IconButton(
                tooltip: 'Lihat detail user',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminUserDetailScreen(userId: userId),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.account_circle_outlined,
                  color: _primaryBlue,
                  size: 27,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressCard({
    required String pickupAddress,
    required String destinationAddress,
    required String pickupTime,
  }) {
    return _sectionCard(
      title: 'Pickup & Pengantaran',
      child: Column(
        children: [
          _buildAddressRow(
            title: 'Pickup',
            address: pickupAddress,
            time: pickupTime,
            color: const Color(0xFF0066FF),
            icon: Icons.radio_button_checked_rounded,
          ),
          const SizedBox(height: 17),
          _buildAddressRow(
            title: 'Tujuan',
            address: destinationAddress,
            time: 'Estimated',
            color: _successGreen,
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required String title,
    required String address,
    required String time,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(time, style: GoogleFonts.inter(color: _textGrey, fontSize: 10.5)),
      ],
    );
  }

  Widget _buildOrderInformationCard({
    required AdminViewModel admin,
    required String itemDescription,
    required String weight,
    required dynamic distanceKm,
    required dynamic totalCost,
  }) {
    return _sectionCard(
      title: 'Order Info',
      child: Column(
        children: [
          _buildInfoRow('Item', itemDescription),
          _buildInfoRow('Weight', weight),
          _buildInfoRow('Distance', admin.formatDistanceText(distanceKm)),
          _buildInfoRow(
            'Total Cost',
            admin.formatCurrency(totalCost),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProofPhotoCard(String source) {
    return _sectionCard(
      title: 'Proof of Delivery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _buildProofPhoto(source),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: _successGreen,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Foto ini diambil oleh driver sebagai bukti bahwa paket telah selesai dikirim.',
                  style: GoogleFonts.inter(
                    color: _textGrey,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofPhoto(String source) {
    final String imageSource = source.trim();

    if (imageSource.isEmpty) {
      return _buildPhotoError('Foto bukti belum tersedia');
    }

    final bool isNetworkImage =
        imageSource.startsWith('http://') || imageSource.startsWith('https://');

    if (isNetworkImage) {
      return Image.network(
        imageSource,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const ColoredBox(
            color: Color(0xFFF2F5F9),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        },
        errorBuilder: (_, __, ___) {
          return _buildPhotoError('Foto dari internet gagal dimuat');
        },
      );
    }

    final Uint8List? imageBytes = _decodeBase64Image(imageSource);

    if (imageBytes == null || imageBytes.isEmpty) {
      return _buildPhotoError('Format foto bukti tidak valid');
    }

    return Image.memory(
      imageBytes,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        return _buildPhotoError('Foto bukti tidak dapat ditampilkan');
      },
    );
  }

  Uint8List? _decodeBase64Image(String source) {
    try {
      String cleanedSource = source.trim();

      if (cleanedSource.contains(',')) {
        cleanedSource = cleanedSource.split(',').last;
      }

      cleanedSource = cleanedSource.replaceAll(RegExp(r'\s+'), '');

      if (cleanedSource.isEmpty) {
        return null;
      }

      return base64Decode(cleanedSource);
    } catch (error) {
      debugPrint('Gagal decode foto bukti: $error');

      return null;
    }
  }

  Widget _buildPhotoError(String message) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF2F5F9),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: _titleBlue, size: 45),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _titleBlue, size: 48),
          const SizedBox(height: 12),
          Text(text, style: GoogleFonts.inter(color: _textGrey, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatOrderId(String value) {
    final String cleanId = value
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortId';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return _successGreen;

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFD14343);

      case 'pending':
        return const Color(0xFFE08B00);

      default:
        return const Color(0xFF0066FF);
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFE2F9EB);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFFFE8E8);

      case 'pending':
        return const Color(0xFFFFF3D8);

      default:
        return const Color(0xFFE7F0FF);
    }
  }
}
