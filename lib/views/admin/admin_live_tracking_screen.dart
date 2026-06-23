import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class AdminLiveTrackingScreen extends StatelessWidget {
  final String orderId;

  const AdminLiveTrackingScreen({super.key, required this.orderId});

  static const Color _primaryBlue = Color(0xFF133D87);

  static const Color _titleBlue = Color(0xFF608BC0);

  static const Color _textGrey = Color(0xFF687386);

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.hasError) {
            return _buildMessage(
              context: context,
              icon: Icons.error_outline_rounded,
              text: 'Gagal memuat data live tracking.',
            );
          }

          if (!orderSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            );
          }

          if (orderSnapshot.data?.exists != true) {
            return _buildMessage(
              context: context,
              icon: Icons.route_outlined,
              text: 'Order tidak ditemukan.',
            );
          }

          final Map<String, dynamic> orderData =
              orderSnapshot.data!.data() ?? {};

          final String driverId = orderData['driver_id']?.toString() ?? '';

          if (driverId.isEmpty) {
            return _buildMessage(
              context: context,
              icon: Icons.delivery_dining_outlined,
              text: 'Driver belum tersedia.',
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('driver_locations')
                .doc(driverId)
                .snapshots(),
            builder: (context, driverSnapshot) {
              if (driverSnapshot.hasError) {
                return _buildMessage(
                  context: context,
                  icon: Icons.location_off_outlined,
                  text: 'Lokasi driver gagal dimuat.',
                );
              }

              final Map<String, dynamic> driverData =
                  driverSnapshot.data?.data() ?? {};

              final double? driverLat = _toDouble(
                driverData['latitude'] ??
                    driverData['lat'] ??
                    orderData['driver_lat'],
              );

              final double? driverLng = _toDouble(
                driverData['longitude'] ??
                    driverData['lng'] ??
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

              if (driverLat == null || driverLng == null) {
                return _buildMessage(
                  context: context,
                  icon: Icons.location_searching_rounded,
                  text: 'Koordinat driver belum tersedia.',
                );
              }

              final LatLng driverPosition = LatLng(driverLat, driverLng);

              final LatLng? pickupPosition =
                  pickupLat != null && pickupLng != null
                  ? LatLng(pickupLat, pickupLng)
                  : null;

              final LatLng? destinationPosition =
                  destinationLat != null && destinationLng != null
                  ? LatLng(destinationLat, destinationLng)
                  : null;

              final List<LatLng> routePoints = [
                if (pickupPosition != null) pickupPosition,
                driverPosition,
                if (destinationPosition != null) destinationPosition,
              ];

              final String status = orderData['status']?.toString() ?? '-';

              return Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: driverPosition,
                      initialZoom: 15,
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
                              color: _primaryBlue,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: driverPosition,
                            width: 54,
                            height: 54,
                            child: const _LiveMarker(
                              icon: Icons.delivery_dining_rounded,
                              color: _primaryBlue,
                            ),
                          ),
                          if (pickupPosition != null)
                            Marker(
                              point: pickupPosition,
                              width: 48,
                              height: 48,
                              child: const _LiveMarker(
                                icon: Icons.inventory_2_rounded,
                                color: Color(0xFFFF9F1C),
                              ),
                            ),
                          if (destinationPosition != null)
                            Marker(
                              point: destinationPosition,
                              width: 48,
                              height: 48,
                              child: const _LiveMarker(
                                icon: Icons.location_on_rounded,
                                color: Color(0xFFFF4A45),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: _primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.13),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Live Tracking',
                                    style: GoogleFonts.inter(
                                      color: _primaryBlue,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    status,
                                    style: GoogleFonts.inter(
                                      color: _textGrey,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 28,
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _titleBlue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: _primaryBlue,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver Location',
                                  style: GoogleFonts.inter(
                                    color: _primaryBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lokasi diperbarui secara real-time.',
                                  style: GoogleFonts.inter(
                                    color: _textGrey,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0AAA55),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessage({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_rounded, color: _primaryBlue),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: _titleBlue, size: 50),
                    const SizedBox(height: 13),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LiveMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 27),
    );
  }
}
