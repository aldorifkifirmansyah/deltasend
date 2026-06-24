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

class AdminLiveTrackingScreen extends StatefulWidget {
  final String orderId;

  const AdminLiveTrackingScreen({super.key, required this.orderId});

  @override
  State<AdminLiveTrackingScreen> createState() =>
      _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState extends State<AdminLiveTrackingScreen> {
  final MapController _mapController = MapController();

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

  void _zoomIn() {
    final camera = _mapController.camera;

    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    final camera = _mapController.camera;

    _mapController.move(camera.center, camera.zoom - 1);
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
                            stream: FirebaseFirestore.instance
                                .collection('orders')
                                .doc(widget.orderId)
                                .snapshots(),
                            builder: (context, orderSnapshot) {
                              if (orderSnapshot.hasError) {
                                return _buildMessage(
                                  icon: Icons.error_outline_rounded,
                                  text: 'Gagal memuat live tracking.',
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
                                  text: 'Order tidak ditemukan.',
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

    final String shortId = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();

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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 23),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 400,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 14.5,
                      ),
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
                                width: 52,
                                height: 52,
                                child: const _MapMarker(
                                  color: _primaryBlue,
                                  icon: Icons.delivery_dining_rounded,
                                ),
                              ),
                            if (hasDestination)
                              Marker(
                                point: LatLng(destinationLat, destinationLng),
                                width: 47,
                                height: 47,
                                child: const _MapMarker(
                                  color: Color(0xFFE85B5B),
                                  icon: Icons.location_on_rounded,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 14,
                      bottom: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _ZoomButton(
                              icon: Icons.add_rounded,
                              onTap: _zoomIn,
                            ),
                            const SizedBox(
                              width: 43,
                              child: Divider(height: 1),
                            ),
                            _ZoomButton(
                              icon: Icons.remove_rounded,
                              onTap: _zoomOut,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 17),
              Text(
                item,
                style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
              ),
              const SizedBox(height: 25),
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
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ETA',
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Distance Remaining',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eta,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      distanceRemaining,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
            'Live Tracking',
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

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: const Color(0xFF202832), size: 25),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 7),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 25),
    );
  }
}
