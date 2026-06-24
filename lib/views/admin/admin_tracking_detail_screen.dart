import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_live_tracking_screen.dart';

class AdminTrackingDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminTrackingDetailScreen({super.key, required this.orderId});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF202832);
  static const Color _textGrey = Color(0xFF858E99);
  static const Color _borderColor = Color(0xFFE0E5EA);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _normalizeStatus(String status) {
    return status.trim().replaceAll('_', '').replaceAll(' ', '').toLowerCase();
  }

  bool _isCompleted(String status) {
    return _normalizeStatus(status) == 'completed';
  }

  int _statusStep(String status) {
    switch (_normalizeStatus(status)) {
      case 'accepted':
      case 'pickingup':
        return 1;

      case 'delivering':
      case 'ondelivery':
        return 2;

      case 'completed':
        return 3;

      default:
        return 0;
    }
  }

  Color _statusTextColor(String status) {
    if (_isCompleted(status)) {
      return const Color(0xFF24A96B);
    }

    return const Color(0xFF3E7FC7);
  }

  Color _statusBackgroundColor(String status) {
    if (_isCompleted(status)) {
      return const Color(0xFFE1F8EB);
    }

    return const Color(0xFFE6F1FF);
  }

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
                            builder: (context, orderSnapshot) {
                              if (orderSnapshot.hasError) {
                                return _buildMessage(
                                  icon: Icons.error_outline_rounded,
                                  text: 'Gagal memuat detail tracking.',
                                );
                              }

                              if (!orderSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
                                );
                              }

                              if (orderSnapshot.data?.exists != true) {
                                return _buildMessage(
                                  icon: Icons.route_outlined,
                                  text: 'Tracking tidak ditemukan.',
                                );
                              }

                              final orderData =
                                  orderSnapshot.data!.data() ?? {};

                              final String driverId =
                                  orderData['driver_id']?.toString() ?? '';

                              return StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: driverId.isEmpty
                                    ? null
                                    : FirebaseFirestore.instance
                                          .collection('driver_locations')
                                          .doc(driverId)
                                          .snapshots(),
                                builder: (context, locationSnapshot) {
                                  final driverLocation =
                                      locationSnapshot.data?.data() ?? {};

                                  return StreamBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>
                                  >(
                                    stream: driverId.isEmpty
                                        ? null
                                        : FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(driverId)
                                              .snapshots(),
                                    builder: (context, driverSnapshot) {
                                      final driverData =
                                          driverSnapshot.data?.data() ?? {};

                                      return _buildContent(
                                        context: context,
                                        admin: admin,
                                        orderData: orderData,
                                        driverLocation: driverLocation,
                                        driverData: driverData,
                                        driverId: driverId,
                                      );
                                    },
                                  );
                                },
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 3),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AdminViewModel admin,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> driverLocation,
    required Map<String, dynamic> driverData,
    required String driverId,
  }) {
    final String status = orderData['status']?.toString() ?? '';

    final String item =
        orderData['item_description']?.toString().trim().isNotEmpty == true
        ? orderData['item_description'].toString().trim()
        : 'Paket';

    final String shortId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    final double? driverLat = _toDouble(
      driverLocation['latitude'] ??
          driverLocation['lat'] ??
          orderData['driver_lat'],
    );

    final double? driverLng = _toDouble(
      driverLocation['longitude'] ??
          driverLocation['lng'] ??
          orderData['driver_lng'],
    );

    final double? pickupLat = _toDouble(orderData['pickup_lat']);

    final double? pickupLng = _toDouble(orderData['pickup_lng']);

    final double? destinationLat = _toDouble(
      orderData['dest_lat'] ?? orderData['destination_lat'],
    );

    final double? destinationLng = _toDouble(
      orderData['dest_lng'] ?? orderData['destination_lng'],
    );

    final bool hasDriver = driverLat != null && driverLng != null;

    final bool hasPickup = pickupLat != null && pickupLng != null;

    final bool hasDestination =
        destinationLat != null && destinationLng != null;

    final LatLng center = hasDriver
        ? LatLng(driverLat, driverLng)
        : hasDestination
        ? LatLng(destinationLat, destinationLng)
        : hasPickup
        ? LatLng(pickupLat, pickupLng)
        : const LatLng(-8.1680, 113.7020);

    final List<LatLng> routePoints = [
      if (hasPickup) LatLng(pickupLat, pickupLng),
      if (hasDriver) LatLng(driverLat, driverLng),
      if (hasDestination) LatLng(destinationLat, destinationLng),
    ];

    final dynamic ratingValue =
        driverData['rating_avg'] ??
        driverData['rating_average'] ??
        driverData['average_rating'] ??
        driverData['rating'] ??
        0;

    final dynamic ratingCountValue =
        driverData['rating_count'] ?? driverData['total_rating'] ?? 0;

    final double rating = double.tryParse(ratingValue.toString()) ?? 0;

    final int ratingCount = int.tryParse(ratingCountValue.toString()) ?? 0;

    final String driverName =
        driverData['name']?.toString().trim().isNotEmpty == true
        ? driverData['name'].toString().trim()
        : driverId.isEmpty
        ? 'Driver belum tersedia'
        : 'Driver';

    final String driverPhone =
        (driverData['phone'] ?? driverData['phone_number'] ?? '-').toString();

    final String driverPhoto =
        (driverData['photo_url'] ?? driverData['photoUrl'] ?? '').toString();

    final String distanceRemaining = _isCompleted(status)
        ? '0 KM'
        : hasDriver && hasDestination
        ? admin.formatRemainingDistance(
            driverLat: driverLat,
            driverLng: driverLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
          )
        : '-';

    final dynamic etaValue =
        orderData['estimated_time'] ??
        orderData['eta'] ??
        orderData['duration_text'];

    final String eta = _isCompleted(status)
        ? 'Selesai'
        : etaValue?.toString().trim().isNotEmpty == true
        ? etaValue.toString()
        : '-';

    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 24, 25, 120),
      children: [
        _buildHeader(context),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#ORD-$shortId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
                ],
              ),
              const SizedBox(height: 13),
              Text(
                item,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                admin.formatTime(orderData['created_at']),
                style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Container(
                height: 270,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.deltasend',
                    ),
                    if (routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 5,
                            color: _titleBlue,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (hasPickup)
                          Marker(
                            point: LatLng(pickupLat, pickupLng),
                            width: 44,
                            height: 44,
                            child: const _MapMarker(
                              color: Color(0xFF20B86B),
                              icon: Icons.location_on_rounded,
                            ),
                          ),
                        if (hasDriver)
                          Marker(
                            point: LatLng(driverLat, driverLng),
                            width: 50,
                            height: 50,
                            child: const _MapMarker(
                              color: _primaryBlue,
                              icon: Icons.delivery_dining_rounded,
                            ),
                          ),
                        if (hasDestination)
                          Marker(
                            point: LatLng(destinationLat, destinationLng),
                            width: 46,
                            height: 46,
                            child: const _MapMarker(
                              color: Color(0xFFE85B5B),
                              icon: Icons.location_on_rounded,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
              Text(
                'Driver',
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Container(
                    width: 59,
                    height: 59,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCEEFF),
                      shape: BoxShape.circle,
                    ),
                    child: driverPhoto.isEmpty
                        ? const Icon(
                            Icons.person_rounded,
                            color: _primaryBlue,
                            size: 37,
                          )
                        : Image.network(
                            driverPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person_rounded,
                                color: _primaryBlue,
                                size: 37,
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
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
                          driverPhone,
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : 'Baru',
                    style: GoogleFonts.inter(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB800),
                    size: 23,
                  ),
                ],
              ),
              if (ratingCount > 0) ...[
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$ratingCount rating',
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 10.5),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              _InfoLine(label: 'Estimated Arrival', value: eta),
              const SizedBox(height: 18),
              _InfoLine(label: 'Distance Remaining', value: distanceRemaining),
              const SizedBox(height: 26),
              Text(
                'Delivery Status',
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 17),
              _DeliveryStatus(currentStep: _statusStep(status)),
              const SizedBox(height: 27),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton.icon(
                  onPressed: driverId.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminLiveTrackingScreen(orderId: orderId),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBCC6D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 21),
                  label: Text(
                    'Open Live Tracking',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
          Text(
            'Tracking Detail',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 21,
              fontWeight: FontWeight.w700,
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
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF858E99),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFF202832),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DeliveryStatus extends StatelessWidget {
  final int currentStep;

  const _DeliveryStatus({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusChip(label: 'Accepted', active: currentStep >= 1),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusChip(label: 'On Delivery', active: currentStep >= 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusChip(label: 'Delivered', active: currentStep >= 3),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE1F8EB) : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: active ? const Color(0xFF24A96B) : const Color(0xFF9BA3AC),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
