import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/order_model.dart';
import '../utils/app_assets.dart';
import '../viewmodels/map_viewmodel.dart';
import '../widgets/location_status_banner.dart';
import 'chat/chat_screen.dart';
import 'driver/driver_bottom_bar.dart';
import 'driver/driver_home_screen.dart';

class MapDriverScreen extends StatefulWidget {
  final String orderId;

  const MapDriverScreen({super.key, required this.orderId});

  @override
  State<MapDriverScreen> createState() => _MapDriverScreenState();
}

class _MapDriverScreenState extends State<MapDriverScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String _base64Photo = '';
  bool _isLoading = false;

  // null = lokasi OK; selain itu tampilkan banner masalah lokasi di peta.
  LocationBannerState? _locationProblem;

  String? _cachedCustomerId;
  Future<Map<String, dynamic>?>? _customerFuture;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _successGreen = Color(0xFF0AAA55);
  static const Color _dangerRed = Color(0xFFD14343);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final MapViewModel viewModel = context.read<MapViewModel>();

      viewModel.setTickerProvider(this);
      viewModel.fetchOrderData(widget.orderId);
      viewModel.initLocation();

      _refreshLocationState();
    });
  }

  // Cek status GPS/izin (read-only, tidak request) untuk ditampilkan ke driver.
  Future<void> _refreshLocationState() async {
    try {
      final bool serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceOn) {
        setState(() => _locationProblem = LocationBannerState.serviceOff);
        return;
      }

      final LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationProblem = LocationBannerState.deniedForever);
        return;
      }
      if (permission == LocationPermission.denied) {
        setState(() => _locationProblem = LocationBannerState.denied);
        return;
      }

      setState(() => _locationProblem = null);
    } catch (_) {
      if (mounted) {
        setState(() => _locationProblem = LocationBannerState.error);
      }
    }
  }

  // Dipicu dari banner "Coba Lagi": minta ViewModel init ulang + refresh status.
  Future<void> _retryLocation() async {
    context.read<MapViewModel>().initLocation();
    await _refreshLocationState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationState();
    }
  }

  Future<Map<String, dynamic>?>? _getCustomerProfile(String customerId) {
    if (customerId.trim().isEmpty) {
      return null;
    }

    if (_cachedCustomerId != customerId || _customerFuture == null) {
      _cachedCustomerId = customerId;

      _customerFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get()
          .then((document) => document.data())
          .catchError((_) => null);
    }

    return _customerFuture;
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

  Future<void> _captureProofPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25,
        maxWidth: 700,
        maxHeight: 700,
      );

      if (photo == null) return;

      final Uint8List bytes = await photo.readAsBytes();

      if (!mounted) return;

      setState(() {
        _base64Photo = base64Encode(bytes);
      });
    } catch (error) {
      if (!mounted) return;

      _showSnackBar('Gagal mengambil foto: $error');
    }
  }

  Future<void> _completeOrderWithPhoto() async {
    if (_base64Photo.isEmpty || widget.orderId.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final MapViewModel viewModel = context.read<MapViewModel>();

      await viewModel.completeOrderWithPhoto(
        orderId: widget.orderId,
        base64Photo: _base64Photo,
      );

      if (!mounted) return;

      _showSnackBar('Pesanan berhasil diselesaikan.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const DriverHomeScreen(initialIndex: 1),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      _showSnackBar('Gagal menyelesaikan pesanan: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openChat(OrderModel order) {
    final String? driverId = order.driverId;

    if (driverId == null || driverId.trim().isEmpty) {
      _showSnackBar('Data driver belum tersedia.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: order.orderId,
          currentUserId: driverId,
          customerId: order.customerId,
          driverId: driverId,
        ),
      ),
    );
  }

  void _handleBottomNavigation(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => DriverHomeScreen(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MapViewModel viewModel = context.watch<MapViewModel>();

    final LatLng? currentLocation = viewModel.currentLocation;

    final List<LatLng> routePoints = viewModel.routePoints;

    final OrderModel? currentOrder = viewModel.currentOrder;

    if (currentOrder == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        bottomNavigationBar: DriverBottomBar(
          selectedIndex: 1,
          onTap: _handleBottomNavigation,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _primaryBlue),
        ),
      );
    }

    LatLng? targetPoint;
    String headerTitle;
    String statusText;
    String buttonText;
    VoidCallback? buttonOnPressed;
    bool buttonEnabled;

    if (currentOrder.status == OrderStatus.pickingUp ||
        currentOrder.status == OrderStatus.accepted) {
      targetPoint = currentOrder.pickupLocation;
      headerTitle = 'Menuju Penjemputan';
      statusText = 'Pickup Order';
      buttonText = 'Pick Up Pesanan';

      buttonEnabled = viewModel.isAtLocation;

      buttonOnPressed = buttonEnabled ? () => viewModel.updateStatus() : null;
    } else if (currentOrder.status == OrderStatus.delivering) {
      targetPoint = currentOrder.destinationLocation;
      headerTitle = 'Mengantar Pesanan';
      statusText = 'Delivery Order';

      if (viewModel.distanceInMeters > 50) {
        buttonText = 'Menuju Lokasi Tujuan';
        buttonEnabled = false;
        buttonOnPressed = null;
      } else if (_base64Photo.isEmpty) {
        buttonText = 'Ambil Foto Bukti';
        buttonEnabled = true;
        buttonOnPressed = _captureProofPhoto;
      } else {
        buttonText = 'Selesaikan Pesanan';
        buttonEnabled = !_isLoading;
        buttonOnPressed = _isLoading ? null : _completeOrderWithPhoto;
      }
    } else {
      targetPoint = currentOrder.destinationLocation;
      headerTitle = 'Pesanan Selesai';
      statusText = 'Completed';
      buttonText = 'Pesanan Selesai';
      buttonEnabled = false;
      buttonOnPressed = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      extendBody: false,
      bottomNavigationBar: DriverBottomBar(
        selectedIndex: 1,
        onTap: _handleBottomNavigation,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return const ColoredBox(color: Color(0xFFF7F9FC));
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 13),
                SvgPicture.asset(AppAssets.logo, width: 195),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.13),
                          blurRadius: 17,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHeader(order: currentOrder, title: headerTitle),
                        Expanded(
                          child: _buildMap(
                            viewModel: viewModel,
                            currentLocation: currentLocation,
                            targetPoint: targetPoint,
                            routePoints: routePoints,
                          ),
                        ),
                        _buildDeliveryPanel(
                          order: currentOrder,
                          viewModel: viewModel,
                          statusText: statusText,
                          buttonText: buttonText,
                          buttonEnabled: buttonEnabled,
                          buttonOnPressed: buttonOnPressed,
                        ),
                      ],
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

  Widget _buildHeader({required OrderModel order, required String title}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: const BoxDecoration(
        color: _titleBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatOrderId(order.orderId),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Tombol chat tunggal ada di panel info customer (lihat _buildDeliveryPanel).
          // SizedBox penyeimbang supaya judul tetap ter-center terhadap tombol back.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMap({
    required MapViewModel viewModel,
    required LatLng? currentLocation,
    required LatLng? targetPoint,
    required List<LatLng> routePoints,
  }) {
    return Stack(
      children: [
        FlutterMap(
          mapController: viewModel.mapController,
          options: MapOptions(
            initialCenter: currentLocation ?? const LatLng(-8.1689, 113.7022),
            initialZoom: 15,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && viewModel.isAutoCenter) {
                viewModel.disableAutoCenter();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.deltasend.app',
            ),
            if (routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: _primaryBlue,
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (currentLocation != null)
                  Marker(
                    point: currentLocation,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: _primaryBlue,
                        size: 31,
                      ),
                    ),
                  ),
                if (targetPoint != null)
                  Marker(
                    point: targetPoint,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: _dangerRed,
                        size: 31,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (!viewModel.isAutoCenter)
          Positioned(
            top: 13,
            right: 13,
            child: FloatingActionButton.small(
              heroTag: 'driver_recenter',
              backgroundColor: Colors.white,
              foregroundColor: _primaryBlue,
              onPressed: viewModel.enableAutoCenter,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        if (_locationProblem != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: LocationStatusBanner(
              state: _locationProblem!,
              onRetry: _retryLocation,
              margin: EdgeInsets.zero,
            ),
          )
        else if (currentLocation == null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildSearchingChip()),
          ),
      ],
    );
  }

  Widget _buildSearchingChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlue),
          ),
          const SizedBox(width: 10),
          Text(
            'Mencari lokasi...',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPanel({
    required OrderModel order,
    required MapViewModel viewModel,
    required String statusText,
    required String buttonText,
    required bool buttonEnabled,
    required VoidCallback? buttonOnPressed,
  }) {
    final bool goingToPickup =
        order.status == OrderStatus.pickingUp ||
        order.status == OrderStatus.accepted;

    final String targetAddress = goingToPickup
        ? order.pickupAddress
        : order.destinationAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _getCustomerProfile(order.customerId),
            builder: (context, snapshot) {
              final Map<String, dynamic>? data = snapshot.data;

              final String customerName =
                  data?['name'] as String? ?? 'Customer';

              final String customerPhoto = data?['photo_url'] as String? ?? '';

              return Row(
                children: [
                  Container(
                    width: 47,
                    height: 47,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _titleBlue.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: customerPhoto.trim().isEmpty
                        ? const Icon(
                            Icons.person_rounded,
                            color: _primaryBlue,
                            size: 29,
                          )
                        : Image.network(
                            customerPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return const Icon(
                                Icons.person_rounded,
                                color: _primaryBlue,
                                size: 29,
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(
                            color: _titleBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openChat(order),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: _primaryBlue,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInformationBox(
                  icon: Icons.route_rounded,
                  label: 'Jarak',
                  value: viewModel.distanceToTarget,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildInformationBox(
                  icon: Icons.access_time_rounded,
                  label: 'Estimasi',
                  value: viewModel.estimatedTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFDCE5F1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  goingToPickup
                      ? Icons.radio_button_checked_rounded
                      : Icons.location_on_rounded,
                  color: goingToPickup ? _successGreen : _dangerRed,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    targetAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _textGrey,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_base64Photo.isNotEmpty) ...[
            const SizedBox(height: 11),
            _buildPhotoPreview(),
          ],
          if (viewModel.currentLocation == null) ...[
            const SizedBox(height: 11),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _locationProblem != null
                      ? Icons.gps_off_rounded
                      : Icons.location_searching_rounded,
                  size: 15,
                  color: _textGrey,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _locationProblem != null
                        ? 'Aktifkan lokasi untuk melanjutkan.'
                        : 'Menunggu lokasi GPS...',
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: buttonOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonEnabled
                    ? _primaryBlue
                    : const Color(0xFFB8C0CC),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB8C0CC),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.3,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _base64Photo.isEmpty
                              ? Icons.camera_alt_outlined
                              : Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          buttonText,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(color: _textGrey, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    Uint8List? bytes;

    try {
      bytes = base64Decode(_base64Photo);
    } catch (_) {
      bytes = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 65,
              height: 65,
              child: bytes == null
                  ? const ColoredBox(
                      color: Color(0xFFE7ECF2),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _textGrey,
                      ),
                    )
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto bukti telah diambil',
                  style: GoogleFonts.inter(
                    color: _successGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pastikan paket dan lokasi terlihat jelas.',
                  style: GoogleFonts.inter(
                    color: _textGrey,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _captureProofPhoto,
            icon: const Icon(Icons.refresh_rounded, color: _primaryBlue),
          ),
        ],
      ),
    );
  }
}
