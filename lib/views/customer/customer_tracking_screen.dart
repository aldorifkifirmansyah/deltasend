import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/routing_service.dart';
import 'rating_screen.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String orderId;

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final OrderService _orderService = OrderService();
  final RoutingService _routingService = RoutingService();
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  List<LatLng> _routePoints = [];

  LatLng? _lastRouteCalculationPosition;

  bool _isCalculatingRoute = false;

  String? _cachedDriverId;
  Future<Map<String, dynamic>?>? _driverProfileFuture;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _pickupOrange = Color(0xFFFF9F1C);
  static const Color _destinationRed = Color(0xFFFF4A45);
  static const Color _successGreen = Color(0xFF0AAA55);

  Future<Map<String, dynamic>?>? _getDriverProfile(String? driverId) {
    if (driverId == null || driverId.trim().isEmpty) {
      return null;
    }

    if (_cachedDriverId != driverId || _driverProfileFuture == null) {
      _cachedDriverId = driverId;
      _driverProfileFuture = _orderService.fetchDriverProfile(driverId);
    }

    return _driverProfileFuture;
  }

  void _maybeUpdateRoute(LatLng driverPosition, LatLng targetPosition) {
    if (_isCalculatingRoute) return;

    if (_lastRouteCalculationPosition != null && _routePoints.isNotEmpty) {
      final double movedDistance = _distance.as(
        LengthUnit.Meter,
        _lastRouteCalculationPosition!,
        driverPosition,
      );

      if (movedDistance <= 50) return;
    }

    _lastRouteCalculationPosition = driverPosition;

    _calculateRoute(driverPosition, targetPosition);
  }

  Future<void> _calculateRoute(LatLng start, LatLng destination) async {
    _isCalculatingRoute = true;

    try {
      final List<LatLng> points = await _routingService.getRoute(
        start,
        destination,
      );

      if (!mounted) return;

      setState(() {
        _routePoints = points;
      });
    } catch (_) {
      // Rute sebelumnya dipertahankan apabila request gagal.
    } finally {
      _isCalculatingRoute = false;
    }
  }

  void _focusMap(LatLng? driverPosition, LatLng targetPosition) {
    try {
      if (driverPosition == null) {
        _mapController.move(targetPosition, 15);
        return;
      }

      final LatLngBounds bounds = LatLngBounds.fromPoints([
        driverPosition,
        targetPosition,
      ]);

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(50, 100, 50, 330),
        ),
      );
    } catch (_) {}
  }

  void _showChatMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fitur chat dengan driver akan dihubungkan pada tahap berikutnya.',
          style: GoogleFonts.inter(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortenedId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortenedId';
  }

  String _formatCurrency(double value) {
    final String raw = value.toStringAsFixed(0);
    final StringBuffer result = StringBuffer();

    for (int index = 0; index < raw.length; index++) {
      final int remaining = raw.length - index;

      result.write(raw[index]);

      if (remaining > 1 && remaining % 3 == 1) {
        result.write('.');
      }
    }

    return 'Rp. $result';
  }

  String _statusTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Mencari Driver';

      case OrderStatus.accepted:
        return 'Driver Ditemukan';

      case OrderStatus.pickingUp:
        return 'Menuju Lokasi Pickup';

      case OrderStatus.delivering:
        return 'Paket Sedang Diantar';

      case OrderStatus.completed:
        return 'Order Selesai';

      case OrderStatus.cancelled:
        return 'Order Dibatalkan';
    }
  }

  String _statusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Sistem sedang mencari driver terdekat.';

      case OrderStatus.accepted:
        return 'Driver telah menerima order Anda.';

      case OrderStatus.pickingUp:
        return 'Driver sedang menuju lokasi penjemputan.';

      case OrderStatus.delivering:
        return 'Driver sedang mengantar paket ke lokasi tujuan.';

      case OrderStatus.completed:
        return 'Paket telah diterima di lokasi tujuan.';

      case OrderStatus.cancelled:
        return 'Order ini telah dibatalkan.';
    }
  }

  String _targetLabel(OrderStatus status) {
    if (status == OrderStatus.accepted || status == OrderStatus.pickingUp) {
      return 'Lokasi Penjemputan';
    }

    return 'Lokasi Tujuan';
  }

  String _targetAddress(OrderModel order) {
    if (order.status == OrderStatus.accepted ||
        order.status == OrderStatus.pickingUp) {
      return order.pickupAddress;
    }

    return order.destinationAddress;
  }

  LatLng _targetPosition(OrderModel order) {
    if (order.status == OrderStatus.accepted ||
        order.status == OrderStatus.pickingUp) {
      return order.pickupLocation;
    }

    return order.destinationLocation;
  }

  double? _distanceToTarget(LatLng? driverPosition, LatLng targetPosition) {
    if (driverPosition == null) return null;

    return _distance.as(LengthUnit.Kilometer, driverPosition, targetPosition);
  }

  String _distanceLabel(double? distanceKm) {
    if (distanceKm == null) return '-';

    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String _estimateDuration(double? distanceKm) {
    if (distanceKm == null) return '-';

    const double averageSpeedKmPerHour = 25;

    int estimatedMinutes = ((distanceKm / averageSpeedKmPerHour) * 60).ceil();

    if (estimatedMinutes < 1) {
      estimatedMinutes = 1;
    }

    return '$estimatedMinutes menit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<OrderModel?>(
        stream: _orderService.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState('Terjadi kesalahan: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            );
          }

          final OrderModel? order = snapshot.data;

          if (order == null) {
            return _buildErrorState('Order tidak ditemukan.');
          }

          final LatLng destinationPosition = order.destinationLocation;

          final LatLng pickupPosition = order.pickupLocation;

          final LatLng? driverPosition = order.driverLocation;

          final LatLng targetPosition = _targetPosition(order);

          if (driverPosition != null &&
              order.status != OrderStatus.completed &&
              order.status != OrderStatus.cancelled) {
            _maybeUpdateRoute(driverPosition, targetPosition);
          }

          final double? distanceKm = _distanceToTarget(
            driverPosition,
            targetPosition,
          );

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: driverPosition ?? targetPosition,
                  initialZoom: 15,
                  onMapReady: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;

                      _focusMap(driverPosition, targetPosition);
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.deltasend.app',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: _primaryBlue,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (order.status == OrderStatus.accepted ||
                          order.status == OrderStatus.pickingUp)
                        Marker(
                          point: pickupPosition,
                          width: 52,
                          height: 52,
                          child: _MapMarker(
                            icon: CupertinoIcons.location_north_fill,
                            color: _pickupOrange,
                          ),
                        ),
                      if (order.status == OrderStatus.delivering ||
                          order.status == OrderStatus.completed)
                        Marker(
                          point: destinationPosition,
                          width: 52,
                          height: 52,
                          child: _MapMarker(
                            icon: CupertinoIcons.location_solid,
                            color: _destinationRed,
                          ),
                        ),
                      if (order.status == OrderStatus.delivering)
                        Marker(
                          point: pickupPosition,
                          width: 42,
                          height: 42,
                          child: _MapMarker(
                            icon: CupertinoIcons.location_north_fill,
                            color: _pickupOrange,
                            small: true,
                          ),
                        ),
                      if (driverPosition != null)
                        Marker(
                          point: driverPosition,
                          width: 58,
                          height: 58,
                          child: const _DriverMapMarker(),
                        ),
                    ],
                  ),
                ],
              ),

              SafeArea(child: _buildTopHeader(order)),

              Positioned(
                right: 18,
                bottom: 338,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: Icons.my_location_rounded,
                      onTap: () {
                        _focusMap(driverPosition, targetPosition);
                      },
                    ),
                    const SizedBox(height: 10),
                    _MapControlButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: _showChatMessage,
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: _buildTrackingPanel(
                  order: order,
                  distanceKm: distanceKm,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopHeader(OrderModel order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle(order.status),
                  style: GoogleFonts.getFont(
                    'ADLaM Display',
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatOrderId(order.orderId),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showChatMessage,
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingPanel({
    required OrderModel order,
    required double? distanceKm,
  }) {
    if (order.status == OrderStatus.completed) {
      return _buildCompletedPanel(order);
    }

    if (order.status == OrderStatus.cancelled) {
      return _buildCancelledPanel();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDriverInformation(order),
          const Divider(height: 28, color: Color(0xFFE4E9F0)),
          _buildStatusProgress(order.status),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TrackingInformationBox(
                  icon: Icons.route_rounded,
                  label: 'Jarak',
                  value: _distanceLabel(distanceKm),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingInformationBox(
                  icon: Icons.schedule_rounded,
                  label: 'Estimasi',
                  value: _estimateDuration(distanceKm),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackingInformationBox(
                  icon: Icons.payments_outlined,
                  label: 'Ongkir',
                  value: _formatCurrency(order.totalCost),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _titleBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _primaryBlue,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _targetLabel(order.status),
                      style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _targetAddress(order),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.driverLocation == null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _pickupOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Menunggu lokasi driver diperbarui.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8A6117),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverInformation(OrderModel order) {
    final Future<Map<String, dynamic>?>? profileFuture = _getDriverProfile(
      order.driverId,
    );

    if (profileFuture == null) {
      return Row(
        children: [
          const _DriverAvatar(imageUrl: ''),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menunggu Driver',
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusDescription(order.status),
                  style: GoogleFonts.inter(color: _textGrey, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: profileFuture,
      builder: (context, snapshot) {
        final Map<String, dynamic>? driverData = snapshot.data;

        final String driverName = driverData?['name'] as String? ?? 'Driver';

        final String photoUrl = driverData?['photo_url'] as String? ?? '';

        final double rating =
            (driverData?['rating_avg'] as num?)?.toDouble() ?? 0;

        final int ratingCount =
            (driverData?['rating_count'] as num?)?.toInt() ?? 0;

        return Row(
          children: [
            _DriverAvatar(imageUrl: photoUrl),
            const SizedBox(width: 13),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB800),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'Baru',
                        style: GoogleFonts.inter(
                          color: _textDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (ratingCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($ratingCount rating)',
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Material(
              color: _primaryBlue.withValues(alpha: 0.10),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _showChatMessage,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _primaryBlue,
                  size: 21,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusProgress(OrderStatus status) {
    int activeStep;

    if (status == OrderStatus.accepted || status == OrderStatus.pickingUp) {
      activeStep = 1;
    } else if (status == OrderStatus.delivering) {
      activeStep = 2;
    } else if (status == OrderStatus.completed) {
      activeStep = 3;
    } else {
      activeStep = 0;
    }

    return Row(
      children: [
        _ProgressStep(
          icon: Icons.person_pin_circle_outlined,
          label: 'Driver',
          completed: activeStep >= 1,
          active: activeStep == 1,
        ),
        _ProgressLine(completed: activeStep >= 2),
        _ProgressStep(
          icon: Icons.local_shipping_outlined,
          label: 'Delivery',
          completed: activeStep >= 2,
          active: activeStep == 2,
        ),
        _ProgressLine(completed: activeStep >= 3),
        _ProgressStep(
          icon: Icons.check_circle_outline_rounded,
          label: 'Selesai',
          completed: activeStep >= 3,
          active: activeStep == 3,
        ),
      ],
    );
  }

  Widget _buildCompletedPanel(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _successGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _successGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pesanan Telah Tiba!',
            style: GoogleFonts.getFont(
              'ADLaM Display',
              color: _titleBlue,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Paket telah berhasil dikirim ke lokasi tujuan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton.icon(
              onPressed: order.rating == null
                  ? () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => RatingScreen(order: order),
                        ),
                      );
                    }
                  : () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                order.rating == null
                    ? Icons.star_outline_rounded
                    : Icons.home_outlined,
                size: 20,
              ),
              label: Text(
                order.rating == null ? 'Beri Rating' : 'Kembali ke Home',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFD14343), size: 58),
          const SizedBox(height: 12),
          Text(
            'Order Dibatalkan',
            style: GoogleFonts.getFont(
              'ADLaM Display',
              color: const Color(0xFFD14343),
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order ini sudah tidak dapat diproses.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Kembali ke Home',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD14343),
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _textGrey,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Kembali',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool small;

  const _MapMarker({
    required this.icon,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: small ? 28 : 36),
    );
  }
}

class _DriverMapMarker extends StatelessWidget {
  const _DriverMapMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF133D87),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.delivery_dining_rounded,
        color: Colors.white,
        size: 31,
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF133D87), size: 22),
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final String imageUrl;

  const _DriverAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF608BC0).withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: imageUrl.trim().isEmpty
          ? const Icon(Icons.person_rounded, color: Color(0xFF133D87), size: 31)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF133D87),
                  size: 31,
                );
              },
            ),
    );
  }
}

class _TrackingInformationBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrackingInformationBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF608BC0), size: 20),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF6F7784),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1D23),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool completed;
  final bool active;

  const _ProgressStep({
    required this.icon,
    required this.label,
    required this.completed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = completed
        ? const Color(0xFF133D87)
        : const Color(0xFFBCC5D1);

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: completed ? color : const Color(0xFFF1F4F8),
            shape: BoxShape.circle,
            border: active
                ? Border.all(color: const Color(0xFF608BC0), width: 3)
                : null,
          ),
          child: Icon(
            completed && !active ? Icons.check_rounded : icon,
            color: completed ? Colors.white : color,
            size: 18,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: completed
                ? const Color(0xFF1A1D23)
                : const Color(0xFF929CAB),
            fontSize: 10,
            fontWeight: completed ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final bool completed;

  const _ProgressLine({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(left: 5, right: 5, bottom: 20),
        color: completed ? const Color(0xFF133D87) : const Color(0xFFD9E0E9),
      ),
    );
  }
}
