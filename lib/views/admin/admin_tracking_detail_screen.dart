import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../utils/routing_service.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_live_tracking_screen.dart';

class AdminTrackingDetailScreen extends StatelessWidget {
  final String orderId;

  const AdminTrackingDetailScreen({super.key, required this.orderId});

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _pageBackground = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 3),
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
                                return _buildMessage('Gagal memuat tracking.');
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
                                  'Tracking tidak ditemukan.',
                                );
                              }

                              final data = snapshot.data!.data()!;

                              return _buildOrderContent(
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

  Widget _buildOrderContent({
    required BuildContext context,
    required AdminViewModel admin,
    required Map<String, dynamic> data,
  }) {
    final String status = data['status']?.toString() ?? 'pending';

    final String item = data['item_description']?.toString().trim() ?? 'Paket';

    final String driverId = data['driver_id']?.toString().trim() ?? '';

    final LatLng? pickup = _readPoint(
      data,
      const ['pickup_lat'],
      const ['pickup_lng'],
    );

    final LatLng? destination = _readPoint(
      data,
      const ['dest_lat', 'destination_lat'],
      const ['dest_lng', 'destination_lng'],
    );

    if (driverId.isEmpty) {
      return _buildContent(
        context: context,
        admin: admin,
        data: data,
        status: status,
        item: item,
        pickup: pickup,
        destination: destination,
        driverPoint: _readPoint(
          data,
          const ['driver_lat'],
          const ['driver_lng'],
        ),
        driverId: '',
        driverLocationData: const {},
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: admin.watchDriverLocation(driverId),
      builder: (context, locationSnapshot) {
        final locationData =
            locationSnapshot.data?.data() ?? <String, dynamic>{};

        final LatLng? driverPoint = _readDriverPoint(
          locationData,
          fallbackOrderData: data,
        );

        return _buildContent(
          context: context,
          admin: admin,
          data: data,
          status: status,
          item: item,
          pickup: pickup,
          destination: destination,
          driverPoint: driverPoint,
          driverId: driverId,
          driverLocationData: locationData,
        );
      },
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AdminViewModel admin,
    required Map<String, dynamic> data,
    required String status,
    required String item,
    required LatLng? pickup,
    required LatLng? destination,
    required LatLng? driverPoint,
    required String driverId,
    required Map<String, dynamic> driverLocationData,
  }) {
    final LatLng? target = status == 'accepted' || status == 'pickingUp'
        ? pickup
        : destination;

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 34),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatOrderId(orderId),
                            style: GoogleFonts.inter(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _buildStatusChip(admin.statusLabel(status), status),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      item,
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      admin.formatTime(
                        data['updated_at'] ?? data['created_at'],
                      ),
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 225,
                      child: _TrackingRouteMap(
                        pickup: pickup,
                        driver: driverPoint,
                        destination: destination,
                        target: target,
                        interactive: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Driver',
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 13),
                    _buildDriverInfo(admin: admin, driverId: driverId),
                    const SizedBox(height: 22),
                    _RouteInformation(
                      start: driverPoint,
                      target: target,
                      completed: status == 'completed',
                    ),
                    const SizedBox(height: 23),
                    Text(
                      'Delivery Status',
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 13),
                    _buildDeliverySteps(status),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminLiveTrackingScreen(orderId: orderId),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: const Icon(Icons.location_searching_rounded),
                        label: Text(
                          'Open Live Tracking',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              'Tracking Detail',
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

  Widget _buildDriverInfo({
    required AdminViewModel admin,
    required String driverId,
  }) {
    if (driverId.isEmpty) {
      return Text(
        'Belum ada driver',
        style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: admin.watchUserDetail(driverId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final String name = data?['name']?.toString() ?? 'Driver';

        final String phone = data?['phone']?.toString() ?? '-';

        final String photoUrl = data?['photo_url']?.toString().trim() ?? '';

        final String rating = admin.formatRating(data?['rating_avg']);

        return Row(
          children: [
            Container(
              width: 51,
              height: 51,
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
                    name,
                    style: GoogleFonts.inter(
                      color: _textDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              rating,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 21),
          ],
        );
      },
    );
  }

  Widget _buildDeliverySteps(String status) {
    final int currentStep;

    switch (status) {
      case 'completed':
        currentStep = 3;
        break;

      case 'delivering':
      case 'onDelivery':
        currentStep = 2;
        break;

      case 'accepted':
      case 'pickingUp':
        currentStep = 1;
        break;

      default:
        currentStep = 0;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStepChip('Accepted', currentStep >= 1),
        _buildStepChip('On Delivery', currentStep >= 2),
        _buildStepChip('Delivered', currentStep >= 3),
      ],
    );
  }

  Widget _buildStepChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE2F9EB) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: active ? const Color(0xFF0AAA55) : const Color(0xFF9AA6B2),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: status == 'completed'
            ? const Color(0xFFE2F9EB)
            : const Color(0xFFE7F0FF),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: status == 'completed'
              ? const Color(0xFF0AAA55)
              : const Color(0xFF0066FF),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  LatLng? _readPoint(
    Map<String, dynamic> data,
    List<String> latitudeKeys,
    List<String> longitudeKeys,
  ) {
    double? latitude;
    double? longitude;

    for (final key in latitudeKeys) {
      latitude = double.tryParse(data[key]?.toString() ?? '');

      if (latitude != null) break;
    }

    for (final key in longitudeKeys) {
      longitude = double.tryParse(data[key]?.toString() ?? '');

      if (longitude != null) break;
    }

    if (latitude == null ||
        longitude == null ||
        latitude == 0 ||
        longitude == 0) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  LatLng? _readDriverPoint(
    Map<String, dynamic> locationData, {
    required Map<String, dynamic> fallbackOrderData,
  }) {
    return _readPoint(
          locationData,
          const ['latitude', 'lat', 'driver_lat'],
          const ['longitude', 'lng', 'driver_lng'],
        ) ??
        _readPoint(
          fallbackOrderData,
          const ['driver_lat'],
          const ['driver_lng'],
        );
  }

  String _formatOrderId(String value) {
    final String clean = value
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    return '#ORD-${clean.length > 8 ? clean.substring(0, 8) : clean}';
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
      ),
    );
  }
}

class _RouteInformation extends StatelessWidget {
  final LatLng? start;
  final LatLng? target;
  final bool completed;

  const _RouteInformation({
    required this.start,
    required this.target,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return const Column(
        children: [
          _TrackingInfoRow(label: 'Estimated Arrival', value: 'Selesai'),
          SizedBox(height: 13),
          _TrackingInfoRow(label: 'Distance Remaining', value: '0 KM'),
        ],
      );
    }

    if (start == null || target == null) {
      return const Column(
        children: [
          _TrackingInfoRow(label: 'Estimated Arrival', value: '-'),
          SizedBox(height: 13),
          _TrackingInfoRow(label: 'Distance Remaining', value: '-'),
        ],
      );
    }

    return FutureBuilder<RouteInfo>(
      future: RoutingService().getRouteInfo(start!, target!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Column(
            children: [
              _TrackingInfoRow(
                label: 'Estimated Arrival',
                value: 'Menghitung...',
              ),
              SizedBox(height: 13),
              _TrackingInfoRow(
                label: 'Distance Remaining',
                value: 'Menghitung...',
              ),
            ],
          );
        }

        final RouteInfo info = snapshot.data!;

        final int minutes = (info.durationSeconds / 60).ceil();

        final String distance = info.distanceMeters >= 1000
            ? '${(info.distanceMeters / 1000).toStringAsFixed(2)} KM'
            : '${info.distanceMeters.toStringAsFixed(0)} M';

        return Column(
          children: [
            _TrackingInfoRow(
              label: 'Estimated Arrival',
              value: '$minutes menit',
            ),
            const SizedBox(height: 13),
            _TrackingInfoRow(label: 'Distance Remaining', value: distance),
          ],
        );
      },
    );
  }
}

class _TrackingInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TrackingInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF687386),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFF1A1D23),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrackingRouteMap extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? driver;
  final LatLng? destination;
  final LatLng? target;
  final bool interactive;

  const _TrackingRouteMap({
    required this.pickup,
    required this.driver,
    required this.destination,
    required this.target,
    required this.interactive,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng center =
        driver ?? pickup ?? destination ?? const LatLng(-8.1689, 113.7022);

    if (driver == null || target == null) {
      return _buildMap(
        center: center,
        routePoints: [
          if (pickup != null) pickup!,
          if (destination != null) destination!,
        ],
      );
    }

    return FutureBuilder<RouteInfo>(
      future: RoutingService().getRouteInfo(driver!, target!),
      builder: (context, snapshot) {
        final List<LatLng> routePoints =
            snapshot.data?.routePoints ?? <LatLng>[driver!, target!];

        return _buildMap(center: center, routePoints: routePoints);
      },
    );
  }

  Widget _buildMap({
    required LatLng center,
    required List<LatLng> routePoints,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.deltasend.app',
          ),
          if (routePoints.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  color: const Color(0xFF1687FF),
                  strokeWidth: 4,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (pickup != null)
                Marker(
                  point: pickup!,
                  width: 38,
                  height: 38,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF0AAA55),
                    size: 34,
                  ),
                ),
              if (driver != null)
                Marker(
                  point: driver!,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF133D87),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              if (destination != null)
                Marker(
                  point: destination!,
                  width: 38,
                  height: 38,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFD14343),
                    size: 34,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
