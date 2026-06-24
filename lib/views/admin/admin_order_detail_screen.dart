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

class AdminOrderDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF202832);
  static const Color _textGrey = Color(0xFF8A929C);
  static const Color _borderColor = Color(0xFFD8E4F0);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.read<AdminViewModel>();

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
                                  25,
                                  24,
                                  120,
                                ),
                                children: [
                                  _buildHeader(context),
                                  const SizedBox(height: 28),

                                  _CustomerHeaderCard(userId: customerId),

                                  const SizedBox(height: 18),

                                  _buildOrderInformation(
                                    admin: admin,
                                    data: data,
                                  ),

                                  const SizedBox(height: 18),

                                  _buildDeliveryLocation(data),

                                  if (driverId.trim().isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    _DriverInformationCard(driverId: driverId),
                                  ],

                                  if (proofValue.trim().isNotEmpty) ...[
                                    const SizedBox(height: 18),
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 2),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              'Order Detail',
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

  Widget _buildOrderInformation({
    required AdminViewModel admin,
    required Map<String, dynamic> data,
  }) {
    final String item =
        data['item_description']?.toString().trim().isNotEmpty == true
        ? data['item_description'].toString().trim()
        : 'Paket';

    final String weight =
        (data['weight_category_name'] ??
                data['weight_category'] ??
                data['weight'] ??
                '-')
            .toString();

    final dynamic distance = data['distance_km'] ?? data['distance'] ?? 0;

    final dynamic totalCost =
        data['total_cost'] ??
        data['shipping_cost'] ??
        data['delivery_fee'] ??
        data['price'] ??
        0;

    final String status = data['status']?.toString() ?? '-';

    return _SectionCard(
      title: 'Order Info',
      children: [
        _InfoRow(label: 'Item', value: item),
        _InfoRow(label: 'Weight', value: weight),
        _InfoRow(label: 'Distance', value: admin.formatDistanceText(distance)),
        _InfoRow(label: 'Status', value: admin.statusLabel(status)),
        _InfoRow(
          label: 'Total Cost',
          value: admin.formatCurrency(totalCost),
          valueColor: _primaryBlue,
          boldValue: true,
          bottomPadding: 0,
        ),
      ],
    );
  }

  Widget _buildDeliveryLocation(Map<String, dynamic> data) {
    final String pickupAddress = data['pickup_address']?.toString() ?? '-';

    final String destinationAddress =
        (data['dest_address'] ?? data['destination_address'] ?? '-').toString();

    return _SectionCard(
      title: 'Delivery Location',
      children: [
        _LocationRow(
          icon: Icons.trip_origin_rounded,
          color: const Color(0xFF20B86B),
          label: 'Pickup',
          value: pickupAddress,
        ),
        const SizedBox(height: 18),
        _LocationRow(
          icon: Icons.location_on_rounded,
          color: const Color(0xFFE85B5B),
          label: 'Destination',
          value: destinationAddress,
        ),
      ],
    );
  }

  Widget _buildProofCard(String proofValue) {
    return _SectionCard(
      title: 'Proof of Delivery',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _buildProofImage(proofValue),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                color: Color(0xFF20B86B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Foto ini diambil oleh driver sebagai bukti bahwa paket telah selesai dikirim.',
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
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
        height: 270,
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
        height: 270,
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
      height: 170,
      color: const Color(0xFFF4F6F9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: _textGrey, size: 40),
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

class _CustomerHeaderCard extends StatelessWidget {
  final String userId;

  const _CustomerHeaderCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) {
      return const _PersonHeaderCard(
        name: 'Customer tidak tersedia',
        email: '-',
        photoUrl: '',
        trailingIcon: Icons.person_outline_rounded,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 118,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF133D87)),
            ),
          );
        }

        final Map<String, dynamic> data = snapshot.data?.data() ?? {};

        final String name = data['name']?.toString().trim().isNotEmpty == true
            ? data['name'].toString().trim()
            : 'Customer';

        final String email = data['email']?.toString() ?? '-';

        final String photoUrl = (data['photo_url'] ?? data['photoUrl'] ?? '')
            .toString();

        return _PersonHeaderCard(
          name: name,
          email: email,
          photoUrl: photoUrl,
          trailingIcon: Icons.account_circle_outlined,
        );
      },
    );
  }
}

class _DriverInformationCard extends StatelessWidget {
  final String driverId;

  const _DriverInformationCard({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF133D87)),
            ),
          );
        }

        final Map<String, dynamic> data = snapshot.data?.data() ?? {};

        final String name = data['name']?.toString() ?? 'Driver';

        final String email = data['email']?.toString() ?? '-';

        final String phone = (data['phone'] ?? data['phone_number'] ?? '-')
            .toString();

        return _SectionCard(
          title: 'Driver Information',
          children: [
            _InfoRow(label: 'Name', value: name),
            _InfoRow(label: 'Email', value: email),
            _InfoRow(label: 'Phone', value: phone, bottomPadding: 0),
          ],
        );
      },
    );
  }
}

class _PersonHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String photoUrl;
  final IconData trailingIcon;

  const _PersonHeaderCard({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD8E4F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0xFFDCEEFF),
              shape: BoxShape.circle,
            ),
            child: photoUrl.trim().isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF133D87),
                    size: 38,
                  )
                : Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF133D87),
                        size: 38,
                      );
                    },
                  ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF202832),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8A929C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(trailingIcon, color: const Color(0xFF133D87), size: 34),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD8E4F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF202832),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool boldValue;
  final double bottomPadding;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.boldValue = false,
    this.bottomPadding = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8A929C),
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? const Color(0xFF333A43),
                fontSize: 13,
                fontWeight: boldValue ? FontWeight.w800 : FontWeight.w600,
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
  final Color color;
  final String label;
  final String value;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF8A929C),
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: const Color(0xFF333A43),
                  fontSize: 12.5,
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
