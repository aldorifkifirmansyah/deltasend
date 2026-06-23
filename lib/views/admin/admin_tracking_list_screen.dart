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
import 'admin_tracking_detail_screen.dart';

class AdminTrackingListScreen extends StatefulWidget {
  const AdminTrackingListScreen({super.key});

  @override
  State<AdminTrackingListScreen> createState() =>
      _AdminTrackingListScreenState();
}

class _AdminTrackingListScreenState extends State<AdminTrackingListScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _pageBackground = Color(0xFFF7F9FC);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTrackingDetail(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminTrackingDetailScreen(orderId: orderId),
      ),
    );
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
                      child: Column(
                        children: [
                          _buildHeader(),
                          _buildSearchField(admin),
                          _buildStatusFilters(admin),
                          Expanded(child: _buildTrackingStream(admin)),
                        ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Text(
              'Tracking',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
            },
            icon: const Icon(Icons.search_rounded, color: _textDark, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AdminViewModel admin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          admin.changeOrderSearchQuery(value);
          setState(() {});
        },
        style: GoogleFonts.inter(color: _textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search order, item, or address...',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF9AA6B2),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9AA6B2),
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    admin.changeOrderSearchQuery('');
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          filled: true,
          fillColor: const Color(0xFFF2F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildStatusFilters(AdminViewModel admin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 17),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(admin: admin, label: 'All', value: 'all'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterButton(
              admin: admin,
              label: 'On Delivery',
              value: 'onDelivery',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterButton(
              admin: admin,
              label: 'Completed',
              value: 'completed',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required AdminViewModel admin,
    required String label,
    required String value,
  }) {
    final bool selected = admin.selectedOrderStatus == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          admin.changeOrderStatus(value);
        },
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0F6FF) : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? _primaryBlue : const Color(0xFFF0F1F3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: selected ? _primaryBlue : _textGrey,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingStream(AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStateMessage(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat tracking',
            description: 'Periksa koneksi dan konfigurasi Firebase.',
            isError: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders =
            documents.where((document) {
              final Map<String, dynamic> data = document.data();

              final String status = data['status']?.toString().trim() ?? '';

              final bool canBeTracked = _isTrackingStatus(status);

              final bool statusMatches = _isTrackingFilterMatch(
                selectedFilter: admin.selectedOrderStatus,
                orderStatus: status,
              );

              final bool searchMatches = admin.isOrderMatchSearch(
                document.id,
                data,
              );

              return canBeTracked && statusMatches && searchMatches;
            }).toList();

        orders.sort((a, b) {
          final dynamic aTimestamp =
              a.data()['updated_at'] ?? a.data()['created_at'];

          final dynamic bTimestamp =
              b.data()['updated_at'] ?? b.data()['created_at'];

          final DateTime aDate = aTimestamp is Timestamp
              ? aTimestamp.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          final DateTime bDate = bTimestamp is Timestamp
              ? bTimestamp.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        if (orders.isEmpty) {
          return _buildStateMessage(
            icon: Icons.route_outlined,
            title: 'Tracking tidak ditemukan',
            description: 'Belum ada order yang sesuai dengan filter.',
          );
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            itemCount: orders.length,
            separatorBuilder: (_, __) {
              return const Divider(height: 1, color: Color(0xFFEDF0F4));
            },
            itemBuilder: (context, index) {
              final document = orders[index];

              return _buildTrackingItem(
                admin: admin,
                orderId: document.id,
                data: document.data(),
              );
            },
          ),
        );
      },
    );
  }

  bool _isTrackingStatus(String status) {
    return status == 'accepted' ||
        status == 'pickingUp' ||
        status == 'delivering' ||
        status == 'onDelivery' ||
        status == 'completed';
  }

  bool _isTrackingFilterMatch({
    required String selectedFilter,
    required String orderStatus,
  }) {
    if (selectedFilter == 'all') {
      return true;
    }

    if (selectedFilter == 'onDelivery') {
      return orderStatus == 'accepted' ||
          orderStatus == 'pickingUp' ||
          orderStatus == 'delivering' ||
          orderStatus == 'onDelivery';
    }

    if (selectedFilter == 'completed') {
      return orderStatus == 'completed';
    }

    return true;
  }

  Widget _buildTrackingItem({
    required AdminViewModel admin,
    required String orderId,
    required Map<String, dynamic> data,
  }) {
    final String status = data['status']?.toString() ?? 'pending';

    final String item = data['item_description']?.toString().trim() ?? '';

    final String destination =
        (data['dest_address'] ?? data['destination_address'])
            ?.toString()
            .trim() ??
        '';

    final String description = item.isNotEmpty
        ? item
        : destination.isNotEmpty
        ? destination
        : 'Paket';

    final LatLng? pickupPoint = _readPoint(
      data,
      latitudeKeys: const ['pickup_lat', 'pickupLatitude'],
      longitudeKeys: const ['pickup_lng', 'pickupLongitude'],
    );

    final LatLng? destinationPoint = _readPoint(
      data,
      latitudeKeys: const [
        'dest_lat',
        'destination_lat',
        'destinationLatitude',
      ],
      longitudeKeys: const [
        'dest_lng',
        'destination_lng',
        'destinationLongitude',
      ],
    );

    final String driverId = data['driver_id']?.toString().trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _openTrackingDetail(orderId);
        },
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 103,
                child: driverId.isEmpty
                    ? _TrackingMapPreview(
                        pickup: pickupPoint,
                        driver: _readPoint(
                          data,
                          latitudeKeys: const ['driver_lat', 'driverLatitude'],
                          longitudeKeys: const [
                            'driver_lng',
                            'driverLongitude',
                          ],
                        ),
                        destination: destinationPoint,
                      )
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: admin.watchDriverLocation(driverId),
                        builder: (context, locationSnapshot) {
                          final Map<String, dynamic> locationData =
                              locationSnapshot.data?.data() ??
                              <String, dynamic>{};

                          final LatLng? driverPoint =
                              _readPoint(
                                locationData,
                                latitudeKeys: const [
                                  'latitude',
                                  'lat',
                                  'driver_lat',
                                ],
                                longitudeKeys: const [
                                  'longitude',
                                  'lng',
                                  'driver_lng',
                                ],
                              ) ??
                              _readPoint(
                                data,
                                latitudeKeys: const [
                                  'driver_lat',
                                  'driverLatitude',
                                ],
                                longitudeKeys: const [
                                  'driver_lng',
                                  'driverLongitude',
                                ],
                              );

                          return _TrackingMapPreview(
                            pickup: pickupPoint,
                            driver: driverPoint,
                            destination: destinationPoint,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatOrderId(orderId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBackground(status),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Text(
                              admin.statusLabel(status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: _statusColor(status),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          admin.formatTime(
                            data['updated_at'] ?? data['created_at'],
                          ),
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA6B0BC),
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng? _readPoint(
    Map<String, dynamic> data, {
    required List<String> latitudeKeys,
    required List<String> longitudeKeys,
  }) {
    double? latitude;
    double? longitude;

    for (final String key in latitudeKeys) {
      latitude = double.tryParse(data[key]?.toString() ?? '');

      if (latitude != null) {
        break;
      }
    }

    for (final String key in longitudeKeys) {
      longitude = double.tryParse(data[key]?.toString() ?? '');

      if (longitude != null) {
        break;
      }
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

    final String shortId = clean.length > 8 ? clean.substring(0, 8) : clean;

    return '#ORD-$shortId';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF0AAA55);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFD14343);

      case 'pending':
        return const Color(0xFFE08B00);

      default:
        return const Color(0xFF0066FF);
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFE2F9EB);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFFFE8E8);

      case 'pending':
        return const Color(0xFFFFF3D8);

      default:
        return const Color(0xFFE7F0FF);
    }
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String description,
    bool isError = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isError ? const Color(0xFFD14343) : _titleBlue,
              size: 46,
            ),
            const SizedBox(height: 11),
            Text(
              title,
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
              style: GoogleFonts.inter(color: _textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingMapPreview extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? driver;
  final LatLng? destination;

  const _TrackingMapPreview({
    required this.pickup,
    required this.driver,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = <LatLng>[
      if (pickup != null) pickup!,
      if (driver != null) driver!,
      if (destination != null) destination!,
    ];

    if (points.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.map_outlined, color: Color(0xFF608BC0)),
      );
    }

    final LatLng center = driver ?? pickup ?? destination!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: IgnorePointer(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.deltasend.app',
            ),
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: const Color(0xFF1687FF),
                    strokeWidth: 3,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (pickup != null)
                  Marker(
                    point: pickup!,
                    width: 25,
                    height: 25,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF0AAA55),
                      size: 24,
                    ),
                  ),
                if (driver != null)
                  Marker(
                    point: driver!,
                    width: 27,
                    height: 27,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF133D87),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                if (destination != null)
                  Marker(
                    point: destination!,
                    width: 25,
                    height: 25,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFD14343),
                      size: 24,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
