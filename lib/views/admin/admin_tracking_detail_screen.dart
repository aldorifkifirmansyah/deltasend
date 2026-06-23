import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_live_tracking_screen.dart';

class AdminTrackingDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminTrackingDetailScreen({super.key, required this.orderId});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1B1B1B);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _borderBlue = Color(0xFFC9D9ED);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

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
                                  text: 'Gagal memuat detail tracking.',
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
                                  icon: Icons.route_outlined,
                                  text: 'Data tracking tidak ditemukan.',
                                );
                              }

                              final Map<String, dynamic> orderData =
                                  snapshot.data!.data() ?? {};

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
                                builder: (context, driverSnapshot) {
                                  final Map<String, dynamic> driverLocation =
                                      driverSnapshot.data?.data() ?? {};

                                  return _buildContent(
                                    context: context,
                                    admin: admin,
                                    orderData: orderData,
                                    driverLocation: driverLocation,
                                    driverId: driverId,
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
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AdminViewModel admin,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> driverLocation,
    required String driverId,
  }) {
    final String status = orderData['status']?.toString() ?? '-';

    final String pickupAddress = orderData['pickup_address']?.toString() ?? '-';

    final String destinationAddress =
        (orderData['dest_address'] ?? orderData['destination_address'] ?? '-')
            .toString();

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

    final double? destinationLat = _toDouble(
      orderData['dest_lat'] ?? orderData['destination_lat'],
    );

    final double? destinationLng = _toDouble(
      orderData['dest_lng'] ?? orderData['destination_lng'],
    );

    final bool hasDriverLocation = driverLat != null && driverLng != null;

    final bool hasDestination =
        destinationLat != null && destinationLng != null;

    final LatLng mapCenter = hasDriverLocation
        ? LatLng(driverLat, driverLng)
        : hasDestination
        ? LatLng(destinationLat, destinationLng)
        : const LatLng(-7.7956, 110.3695);

    final String remainingDistance = hasDriverLocation && hasDestination
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

    final String eta = etaValue?.toString().trim().isNotEmpty == true
        ? etaValue.toString()
        : '-';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 45),
      children: [
        Text(
          'Tracking Detail',
          style: GoogleFonts.getFont(
            'ADLaM Display',
            color: _titleBlue,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Pantau posisi driver dan status pengiriman.',
          style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Container(
          height: 225,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderBlue),
          ),
          child: FlutterMap(
            options: MapOptions(initialCenter: mapCenter, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.deltasend',
              ),
              if (hasDriverLocation && hasDestination)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(driverLat, driverLng),
                        LatLng(destinationLat, destinationLng),
                      ],
                      strokeWidth: 4,
                      color: _primaryBlue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (hasDriverLocation)
                    Marker(
                      point: LatLng(driverLat, driverLng),
                      width: 48,
                      height: 48,
                      child: const _TrackingMarker(
                        icon: Icons.delivery_dining_rounded,
                        color: _primaryBlue,
                      ),
                    ),
                  if (hasDestination)
                    Marker(
                      point: LatLng(destinationLat, destinationLng),
                      width: 46,
                      height: 46,
                      child: const _TrackingMarker(
                        icon: Icons.location_on_rounded,
                        color: Color(0xFFFF4A45),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.timer_outlined,
                label: 'ETA',
                value: eta,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.route_outlined,
                label: 'Remaining Distance',
                value: remainingDistance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TrackingInformationCard(
          status: admin.statusLabel(status),
          pickupAddress: pickupAddress,
          destinationAddress: destinationAddress,
          driverId: driverId,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
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
              disabledBackgroundColor: const Color(0xFFBFC9D8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: const Icon(Icons.map_outlined, size: 21),
            label: Text(
              'OPEN LIVE TRACKING',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
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

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFC9D9ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF608BC0), size: 23),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF687386),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF133D87),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingInformationCard extends StatelessWidget {
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final String driverId;

  const _TrackingInformationCard({
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.driverId,
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
          Text(
            'Tracking Information',
            style: GoogleFonts.inter(
              color: const Color(0xFF133D87),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 17),
          _TrackingRow(
            icon: Icons.info_outline_rounded,
            label: 'Status',
            value: status,
          ),
          const Divider(height: 26),
          _TrackingRow(
            icon: Icons.trip_origin_rounded,
            label: 'Pickup',
            value: pickupAddress,
          ),
          const Divider(height: 26),
          _TrackingRow(
            icon: Icons.location_on_rounded,
            label: 'Destination',
            value: destinationAddress,
          ),
          const Divider(height: 26),
          _TrackingRow(
            icon: Icons.delivery_dining_rounded,
            label: 'Driver',
            value: driverId.isEmpty ? 'Belum tersedia' : 'Driver tersedia',
          ),
        ],
      ),
    );
  }
}

class _TrackingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrackingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF608BC0), size: 22),
        const SizedBox(width: 12),
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
                value,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1B1B1B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TrackingMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 7),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 25),
    );
  }
}
