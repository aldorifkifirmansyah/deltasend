import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import '../utils/distance_helper.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'map_driver_screen.dart';

enum _LocationState { loading, ready, denied, deniedForever, serviceOff, error }

class DriverOrderListScreen extends StatefulWidget {
  final bool embedded;
  final bool compact;

  const DriverOrderListScreen({
    super.key,
    this.embedded = false,
    this.compact = false,
  });

  @override
  State<DriverOrderListScreen> createState() => _DriverOrderListScreenState();
}

class _DriverOrderListScreenState extends State<DriverOrderListScreen> {
  final OrderService _orderService = OrderService();
  final Map<String, Future<Map<String, dynamic>?>> _customerProfileCache = {};

  Future<Map<String, dynamic>?> _fetchCustomerProfile(String customerId) {
    if (customerId.trim().isEmpty) {
      return Future.value(null);
    }

    return _customerProfileCache.putIfAbsent(customerId, () async {
      try {
        final document = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();

        return document.data();
      } catch (_) {
        return null;
      }
    });
  }

  String _formatOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortId';
  }

  String? _processingOrderId;
  late final String _driverId;

  Position? _driverPosition;
  _LocationState _locationState = _LocationState.loading;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _successGreen = Color(0xFF0AAA55);
  static const Color _warningOrange = Color(0xFFE08B00);

  @override
  void initState() {
    super.initState();

    _driverId = context.read<AuthViewModel>().currentUser?.uid ?? '';

    _initDriverLocation();
  }

  Future<void> _initDriverLocation() async {
    if (mounted) {
      setState(() {
        _locationState = _LocationState.loading;
      });
    }

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _driverPosition = null;
          _locationState = _LocationState.serviceOff;
        });

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _driverPosition = null;
          _locationState = _LocationState.deniedForever;
        });

        return;
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _driverPosition = null;
          _locationState = _LocationState.denied;
        });

        return;
      }

      final Position position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _driverPosition = position;
        _locationState = _LocationState.ready;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _driverPosition = null;
        _locationState = _LocationState.error;
      });
    }
  }

  void _openMap(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MapDriverScreen(orderId: orderId)),
    );
  }

  Future<void> _takeOrder(OrderModel order) async {
    if (_processingOrderId != null) return;

    setState(() {
      _processingOrderId = order.orderId;
    });

    try {
      await _orderService.acceptOrder(
        orderId: order.orderId,
        driverId: _driverId,
      );

      if (!mounted) return;

      _openMap(order.orderId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil order: $error',
            style: GoogleFonts.inter(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchActiveOrdersForDriver(_driverId),
      builder: (context, activeSnapshot) {
        final List<OrderModel> activeOrders = activeSnapshot.data ?? [];

        final bool hasActive = activeOrders.isNotEmpty;

        final Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Order Aktif Saya',
              icon: Icons.local_shipping_outlined,
            ),

            const SizedBox(height: 10),

            if (activeOrders.length > 1)
              _buildInformationBanner(
                'Terdeteksi ${activeOrders.length} order aktif. '
                'Selesaikan order lama terlebih dahulu.',
              ),

            _buildActiveContent(activeSnapshot),

            if (!widget.compact) ...[
              const SizedBox(height: 26),

              _buildSectionHeader(
                title: 'Order Tersedia',
                icon: Icons.inventory_2_outlined,
              ),

              const SizedBox(height: 10),

              _buildPendingOrdersSection(hasActive: hasActive),
            ],
          ],
        );

        if (widget.embedded) {
          return RefreshIndicator(
            onRefresh: _initDriverLocation,
            color: _primaryBlue,
            child: ListView(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [content],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _initDriverLocation,
          color: _primaryBlue,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [content],
          ),
        );
      },
    );
  }

  Widget _buildActiveContent(AsyncSnapshot<List<OrderModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
      );
    }

    if (snapshot.hasError) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Gagal memuat order aktif',
        description: '${snapshot.error}',
      );
    }

    final List<OrderModel> orders = snapshot.data ?? [];

    if (orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.delivery_dining_outlined,
        title: 'Tidak ada order aktif',
        description: 'Order yang kamu ambil akan tampil di bagian ini.',
      );
    }

    final Iterable<OrderModel> displayedOrders = widget.compact
        ? orders.take(1)
        : orders;

    return Column(
      children: displayedOrders
          .map(
            (order) => _buildOrderCard(
              order: order,
              showStatus: true,
              buttonText: 'Lanjutkan Pengiriman',
              isProcessing: false,
              onPressed: () => _openMap(order.orderId),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPendingOrdersSection({required bool hasActive}) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchPendingOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat order',
            description: '${snapshot.error}',
          );
        }

        final List<OrderModel> orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Belum ada order tersedia',
            description: 'Order baru akan muncul secara otomatis.',
          );
        }

        final bool isLocked = hasActive || _processingOrderId != null;

        final String buttonText = hasActive
            ? 'Selesaikan Order Aktif'
            : 'Ambil Order';

        if (_driverPosition != null) {
          final rankedOrders = _orderService.sortAndFilterByDistance(
            orders: orders,
            driverPosition: _driverPosition!,
          );

          if (rankedOrders.isEmpty) {
            return _buildEmptyState(
              icon: Icons.location_off_outlined,
              title: 'Tidak ada order terdekat',
              description:
                  'Tidak ada order dalam radius '
                  '${kMaxOrderRadiusKm.toStringAsFixed(0)} km.',
            );
          }

          return Column(
            children: rankedOrders
                .map(
                  (item) => _buildOrderCard(
                    order: item.order,
                    showStatus: false,
                    buttonText: buttonText,
                    isProcessing: _processingOrderId == item.order.orderId,
                    onPressed: isLocked ? null : () => _takeOrder(item.order),
                    driverDistanceKm: item.distanceKm,
                  ),
                )
                .toList(),
          );
        }

        return Column(
          children: [
            if (_locationState != _LocationState.loading)
              _buildLocationBanner(),

            ...orders.map(
              (order) => _buildOrderCard(
                order: order,
                showStatus: false,
                buttonText: buttonText,
                isProcessing: _processingOrderId == order.orderId,
                onPressed: isLocked ? null : () => _takeOrder(order),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _titleBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _primaryBlue, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard({
    required OrderModel order,
    required bool showStatus,
    required String buttonText,
    required bool isProcessing,
    required VoidCallback? onPressed,
    double? driverDistanceKm,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _titleBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _primaryBlue,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchCustomerProfile(order.customerId),
                  builder: (context, snapshot) {
                    final Map<String, dynamic>? customerData = snapshot.data;

                    final String customerName =
                        customerData?['name'] as String? ?? 'Customer';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatOrderId(order.orderId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _textDark,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              color: _textGrey,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: _textGrey,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (showStatus)
                _buildStatusChip(order.status)
              else if (driverDistanceKm != null)
                _buildDistanceBadge(driverDistanceKm),
            ],
          ),

          const Divider(height: 25, color: Color(0xFFE4E9F0)),

          _buildLocationRow(
            icon: CupertinoIcons.location_north_fill,
            color: _successGreen,
            label: 'Pickup',
            value: order.pickupAddress,
          ),

          const SizedBox(height: 12),

          _buildLocationRow(
            icon: CupertinoIcons.location_solid,
            color: const Color(0xFFD14343),
            label: 'Destination',
            value: order.destinationAddress,
          ),

          const Divider(height: 25, color: Color(0xFFE4E9F0)),

          Row(
            children: [
              const Icon(Icons.route_rounded, color: _titleBlue, size: 19),
              const SizedBox(width: 6),
              Text(
                order.distanceKm > 0
                    ? '${order.distanceKm.toStringAsFixed(1)} km'
                    : 'Jarak -',
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                order.totalCost > 0 ? _formatCurrency(order.totalCost) : 'Rp -',
                style: GoogleFonts.inter(
                  color: _primaryBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 47,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.38),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    final String label;
    final Color color;
    final Color background;

    switch (status) {
      case OrderStatus.accepted:
        label = 'Accepted';
        color = const Color(0xFF0066FF);
        background = const Color(0xFFE7F0FF);
        break;

      case OrderStatus.pickingUp:
        label = 'Picking Up';
        color = _warningOrange;
        background = const Color(0xFFFFF3D8);
        break;

      case OrderStatus.delivering:
        label = 'Delivering';
        color = const Color(0xFF0066FF);
        background = const Color(0xFFE7F0FF);
        break;

      case OrderStatus.completed:
        label = 'Completed';
        color = _successGreen;
        background = const Color(0xFFE1F8EB);
        break;

      case OrderStatus.cancelled:
        label = 'Cancelled';
        color = const Color(0xFFD14343);
        background = const Color(0xFFFFE8E8);
        break;

      case OrderStatus.pending:
        label = 'Pending';
        color = _warningOrange;
        background = const Color(0xFFFFF3D8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDistanceBadge(double distanceKm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _titleBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, color: _primaryBlue, size: 13),
          const SizedBox(width: 4),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: GoogleFonts.inter(
              color: _primaryBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBanner() {
    String message;
    String actionLabel;
    VoidCallback action;

    switch (_locationState) {
      case _LocationState.deniedForever:
        message = 'Izin lokasi diblokir permanen.';
        actionLabel = 'Settings';
        action = Geolocator.openAppSettings;
        break;

      case _LocationState.serviceOff:
        message = 'GPS tidak aktif. Semua order ditampilkan.';
        actionLabel = 'Aktifkan';
        action = Geolocator.openLocationSettings;
        break;

      case _LocationState.denied:
        message = 'Izin lokasi ditolak.';
        actionLabel = 'Coba Lagi';
        action = _initDriverLocation;
        break;

      default:
        message = 'Lokasi tidak dapat diperoleh.';
        actionLabel = 'Coba Lagi';
        action = _initDriverLocation;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E0),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF0C95C)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB8860B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFF8A6D00),
                fontSize: 11.5,
              ),
            ),
          ),
          TextButton(
            onPressed: action,
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E0),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFF8A6D00),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
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
}
