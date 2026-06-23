import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminOrderDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

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

                              if (snapshot.data?.exists != true) {
                                return _buildMessage(
                                  icon: Icons.inventory_2_outlined,
                                  text: 'Order tidak ditemukan.',
                                );
                              }

                              final Map<String, dynamic> data =
                                  snapshot.data!.data() ?? {};

                              final String shortId = orderId.length > 8
                                  ? orderId.substring(0, 8).toUpperCase()
                                  : orderId.toUpperCase();

                              final String status =
                                  data['status']?.toString() ?? '';

                              final String customerId =
                                  data['customer_id']?.toString() ?? '';

                              final String driverId =
                                  data['driver_id']?.toString() ?? '';

                              final String proofValue =
                                  (data['proof_photo_url'] ??
                                          data['proof_url'] ??
                                          data['proof_photo_base64'] ??
                                          data['delivery_proof'] ??
                                          '')
                                      .toString();

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  30,
                                  24,
                                  45,
                                ),
                                children: [
                                  Text(
                                    'Order Detail',
                                    style: GoogleFonts.getFont(
                                      'ADLaM Display',
                                      color: _titleBlue,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    '#ORD-$shortId',
                                    style: GoogleFonts.inter(
                                      color: _textGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildOrderSummary(
                                    admin: admin,
                                    data: data,
                                    status: status,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLocationCard(data),
                                  const SizedBox(height: 16),
                                  _UserInformationCard(
                                    title: 'Customer Information',
                                    userId: customerId,
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  _UserInformationCard(
                                    title: 'Driver Information',
                                    userId: driverId,
                                    icon: Icons.delivery_dining_rounded,
                                  ),
                                  if (proofValue.trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _buildProofCard(proofValue),
                                  ],
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

  Widget _buildOrderSummary({
    required AdminViewModel admin,
    required Map<String, dynamic> data,
    required String status,
  }) {
    return _DetailSection(
      title: 'Order Information',
      icon: Icons.inventory_2_outlined,
      children: [
        _InformationRow(
          label: 'Item',
          value: data['item_description']?.toString() ?? 'Paket',
        ),
        _InformationRow(label: 'Status', value: admin.statusLabel(status)),
        _InformationRow(
          label: 'Weight Category',
          value:
              (data['weight_category_name'] ?? data['weight_category'] ?? '-')
                  .toString(),
        ),
        _InformationRow(
          label: 'Distance',
          value: admin.formatDistanceText(
            data['distance_km'] ?? data['distance'] ?? 0,
          ),
        ),
        _InformationRow(
          label: 'Shipping Cost',
          value: admin.formatCurrency(
            data['shipping_cost'] ?? data['delivery_fee'] ?? 0,
          ),
        ),
        _InformationRow(
          label: 'Total Cost',
          value: admin.formatCurrency(data['total_cost'] ?? data['price'] ?? 0),
        ),
        _InformationRow(
          label: 'Created',
          value:
              '${admin.formatDate(data['created_at'])} ${admin.formatTime(data['created_at'])}',
        ),
      ],
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> data) {
    final String pickupAddress = data['pickup_address']?.toString() ?? '-';

    final String destinationAddress =
        (data['dest_address'] ?? data['destination_address'] ?? '-').toString();

    return _DetailSection(
      title: 'Delivery Location',
      icon: Icons.route_rounded,
      children: [
        _LocationRow(
          icon: Icons.trip_origin_rounded,
          iconColor: const Color(0xFF0AAA55),
          label: 'Pickup',
          address: pickupAddress,
        ),
        const SizedBox(height: 14),
        _LocationRow(
          icon: Icons.location_on_rounded,
          iconColor: const Color(0xFFFF4A45),
          label: 'Destination',
          address: destinationAddress,
        ),
      ],
    );
  }

  Widget _buildProofCard(String proofValue) {
    return _DetailSection(
      title: 'Proof of Delivery',
      icon: Icons.image_outlined,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _buildProofImage(proofValue),
        ),
      ],
    );
  }

  Widget _buildProofImage(String value) {
    final String cleanValue = value.trim();

    if (cleanValue.startsWith('http://') || cleanValue.startsWith('https://')) {
      return Image.network(
        cleanValue,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _proofError();
        },
      );
    }

    try {
      final String base64Value = cleanValue.contains(',')
          ? cleanValue.split(',').last
          : cleanValue;

      final Uint8List bytes = base64Decode(base64Value);

      return Image.memory(
        bytes,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _proofError();
        },
      );
    } catch (_) {
      return _proofError();
    }
  }

  Widget _proofError() {
    return Container(
      width: double.infinity,
      height: 150,
      color: const Color(0xFFF4F6F9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: _textGrey, size: 38),
          const SizedBox(height: 8),
          Text(
            'Foto bukti tidak dapat dimuat.',
            style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
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

class _UserInformationCard extends StatelessWidget {
  final String title;
  final String userId;
  final IconData icon;

  const _UserInformationCard({
    required this.title,
    required this.userId,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) {
      return _DetailSection(
        title: title,
        icon: icon,
        children: const [
          _InformationRow(label: 'Status', value: 'Belum tersedia'),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _DetailSection(
            title: title,
            icon: icon,
            children: const [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(color: Color(0xFF133D87)),
                ),
              ),
            ],
          );
        }

        final Map<String, dynamic> data = snapshot.data?.data() ?? {};

        final String name = data['name']?.toString() ?? '-';

        final String email = data['email']?.toString() ?? '-';

        final String phone = (data['phone'] ?? data['phone_number'] ?? '-')
            .toString();

        return _DetailSection(
          title: title,
          icon: icon,
          children: [
            _InformationRow(label: 'Name', value: name),
            _InformationRow(label: 'Email', value: email),
            _InformationRow(label: 'Phone', value: phone),
          ],
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFC9D9ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF133D87), size: 22),
              const SizedBox(width: 9),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFF133D87),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;

  const _InformationRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF687386),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFF1B1B1B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF687386),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1B1B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
