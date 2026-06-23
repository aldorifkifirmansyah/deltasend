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
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _pageBackground = Color(0xFFF7F9FC);

  double _zoom = 14;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

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
                            stream: admin.watchOrderDetail(widget.orderId),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _buildMessage(
                                  'Gagal memuat live tracking.',
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
                                  'Live tracking tidak ditemukan.',
                                );
                              }

                              final data = snapshot.data!.data()!;

                              return _buildOrderContent(
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
    required AdminViewModel admin,
    required Map<String, dynamic> data,
  }) {
    final String status = data['status']?.toString() ?? 'pending';

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
        admin: admin,
        data: data,
        status: status,
        driverId: '',
        pickup: pickup,
        destination: destination,
        driverPoint: _readPoint(
          data,
          const ['driver_lat'],
          const ['driver_lng'],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: admin.watchDriverLocation(driverId),
      builder: (context, locationSnapshot) {
        final locationData =
            locationSnapshot.data?.data() ?? <String, dynamic>{};

        final LatLng? driverPoint =
            _readPoint(
              locationData,
              const ['latitude', 'lat', 'driver_lat'],
              const ['longitude', 'lng', 'driver_lng'],
            ) ??
            _readPoint(data, const ['driver_lat'], const ['driver_lng']);

        return _buildContent(
          admin: admin,
          data: data,
          status: status,
          driverId: driverId,
          pickup: pickup,
          destination: destination,
          driverPoint: driverPoint,
        );
      },
    );
  }

  Widget _buildContent({
    required AdminViewModel admin,
    required Map<String, dynamic> data,
    required String status,
    required String driverId,
    required LatLng? pickup,
    required LatLng? destination,
    required LatLng? driverPoint,
  }) {
    final LatLng? target = status == 'accepted' || status == 'pickingUp'
        ? pickup
        : destination;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 34),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 390,
                      child: _buildMap(
                        pickup: pickup,
                        driver: driverPoint,
                        destination: destination,
                        target: target,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatOrderId(widget.orderId),
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
                    const SizedBox(height: 12),
                    Text(
                      data['item_description']?.toString() ?? 'Paket',
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
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
                    const SizedBox(height: 12),
                    _buildDriverInfo(admin: admin, driverId: driverId),
                    const SizedBox(height: 22),
                    _buildRouteInformation(
                      start: driverPoint,
                      target: target,
                      completed: status == 'completed',
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

  Widget _buildHeader() {
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
              'Live Tracking',
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

  Widget _buildMap({
    required LatLng? pickup,
    required LatLng? driver,
    required LatLng? destination,
    required LatLng? target,
  }) {
    final LatLng center =
        driver ?? pickup ?? destination ?? const LatLng(-8.1689, 113.7022);

    return FutureBuilder<RouteInfo?>(
      future: driver != null && target != null
          ? RoutingService()
                .getRouteInfo(driver, target)
                .then<RouteInfo?>((value) => value)
                .catchError((_) => null)
          : Future<RouteInfo?>.value(null),
      builder: (context, snapshot) {
        final List<LatLng> routePoints =
            snapshot.data?.routePoints ??
            <LatLng>[if (driver != null) driver, if (target != null) target];

        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoom,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      _zoom = position.zoom;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.deltasend.app',
                  ),
                  if (routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: const Color(0xFF1687FF),
                          strokeWidth: 4.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (pickup != null)
                        Marker(
                          point: pickup,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF0AAA55),
                            size: 38,
                          ),
                        ),
                      if (driver != null)
                        Marker(
                          point: driver,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: _primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      if (destination != null)
                        Marker(
                          point: destination,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFD14343),
                            size: 38,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 12,
                bottom: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          _zoom = (_zoom + 1).clamp(3, 18);

                          _mapController.move(
                            _mapController.camera.center,
                            _zoom,
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                      const Divider(height: 1),
                      IconButton(
                        onPressed: () {
                          _zoom = (_zoom - 1).clamp(3, 18);

                          _mapController.move(
                            _mapController.camera.center,
                            _zoom,
                          );
                        },
                        icon: const Icon(Icons.remove_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildRouteInformation({
    required LatLng? start,
    required LatLng? target,
    required bool completed,
  }) {
    if (completed) {
      return const Row(
        children: [
          Expanded(
            child: _SmallInfo(label: 'ETA', value: 'Selesai'),
          ),
          Expanded(
            child: _SmallInfo(
              label: 'Distance Remaining',
              value: '0 KM',
              alignRight: true,
            ),
          ),
        ],
      );
    }

    if (start == null || target == null) {
      return const Row(
        children: [
          Expanded(
            child: _SmallInfo(label: 'ETA', value: '-'),
          ),
          Expanded(
            child: _SmallInfo(
              label: 'Distance Remaining',
              value: '-',
              alignRight: true,
            ),
          ),
        ],
      );
    }

    return FutureBuilder<RouteInfo>(
      future: RoutingService().getRouteInfo(start, target),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Row(
            children: [
              Expanded(
                child: _SmallInfo(label: 'ETA', value: 'Menghitung...'),
              ),
              Expanded(
                child: _SmallInfo(
                  label: 'Distance Remaining',
                  value: 'Menghitung...',
                  alignRight: true,
                ),
              ),
            ],
          );
        }

        final RouteInfo route = snapshot.data!;

        final int minutes = (route.durationSeconds / 60).ceil();

        final String distance = route.distanceMeters >= 1000
            ? '${(route.distanceMeters / 1000).toStringAsFixed(2)} KM'
            : '${route.distanceMeters.toStringAsFixed(0)} M';

        return Row(
          children: [
            Expanded(
              child: _SmallInfo(label: 'ETA', value: '$minutes menit'),
            ),
            Expanded(
              child: _SmallInfo(
                label: 'Distance Remaining',
                value: distance,
                alignRight: true,
              ),
            ),
          ],
        );
      },
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

class _SmallInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _SmallInfo({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignRight ? TextAlign.right : null,
          style: GoogleFonts.inter(
            color: const Color(0xFF687386),
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 10),
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
