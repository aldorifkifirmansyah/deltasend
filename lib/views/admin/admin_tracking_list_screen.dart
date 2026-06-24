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

  final FocusNode _searchFocusNode = FocusNode();

  String _selectedFilter = 'all';
  String _searchQuery = '';

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF202832);
  static const Color _textGrey = Color(0xFF858E99);
  static const Color _borderColor = Color(0xFFE0E5EA);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _normalizeStatus(String status) {
    return status.trim().replaceAll('_', '').replaceAll(' ', '').toLowerCase();
  }

  bool _isOnDelivery(String status) {
    final String normalized = _normalizeStatus(status);

    return normalized == 'accepted' ||
        normalized == 'pickingup' ||
        normalized == 'delivering' ||
        normalized == 'ondelivery';
  }

  bool _isCompleted(String status) {
    return _normalizeStatus(status) == 'completed';
  }

  bool _matchesFilter(String status) {
    switch (_selectedFilter) {
      case 'onDelivery':
        return _isOnDelivery(status);

      case 'completed':
        return _isCompleted(status);

      default:
        return _isOnDelivery(status) || _isCompleted(status);
    }
  }

  bool _matchesSearch(String orderId, Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final String item =
        data['item_description']?.toString().toLowerCase() ?? '';

    final String pickup =
        data['pickup_address']?.toString().toLowerCase() ?? '';

    final String destination =
        (data['dest_address'] ?? data['destination_address'] ?? '')
            .toString()
            .toLowerCase();

    return orderId.toLowerCase().contains(_searchQuery) ||
        item.contains(_searchQuery) ||
        pickup.contains(_searchQuery) ||
        destination.contains(_searchQuery);
  }

  Color _statusTextColor(String status) {
    if (_isCompleted(status)) {
      return const Color(0xFF24A96B);
    }

    if (_isOnDelivery(status)) {
      return const Color(0xFF3E7FC7);
    }

    return _textGrey;
  }

  Color _statusBackgroundColor(String status) {
    if (_isCompleted(status)) {
      return const Color(0xFFE1F8EB);
    }

    if (_isOnDelivery(status)) {
      return const Color(0xFFE6F1FF);
    }

    return const Color(0xFFF1F3F5);
  }

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 31, 22, 120),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 30),
                          _buildSearchField(),
                          const SizedBox(height: 22),
                          _buildFilters(),
                          const SizedBox(height: 22),
                          _buildTrackingList(admin),
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 3),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              'Tracking',
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: () {
                _searchFocusNode.requestFocus();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              icon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF111820),
                size: 33,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      },
      style: GoogleFonts.inter(color: _textDark, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search order, item, or address...',
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFFB2BAC5),
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF9BA6B1),
          size: 25,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.close_rounded, color: _textGrey),
              ),
        filled: true,
        fillColor: const Color(0xFFF3F6F8),
        contentPadding: const EdgeInsets.symmetric(vertical: 19),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _titleBlue, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: _FilterButton(
            label: 'All',
            selected: _selectedFilter == 'all',
            onTap: () {
              setState(() {
                _selectedFilter = 'all';
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterButton(
            label: 'On Delivery',
            selected: _selectedFilter == 'onDelivery',
            onTap: () {
              setState(() {
                _selectedFilter = 'onDelivery';
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilterButton(
            label: 'Completed',
            selected: _selectedFilter == 'completed',
            onTap: () {
              setState(() {
                _selectedFilter = 'completed';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingList(AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            icon: Icons.error_outline_rounded,
            text: 'Gagal memuat data tracking.',
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        }

        final orders = snapshot.data!.docs.where((document) {
          final data = document.data();
          final status = data['status']?.toString() ?? '';

          return _matchesFilter(status) && _matchesSearch(document.id, data);
        }).toList();

        if (orders.isEmpty) {
          return _buildMessage(
            icon: Icons.route_outlined,
            text: 'Data tracking tidak ditemukan.',
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _borderColor),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) {
              return const Divider(height: 18, color: Color(0xFFE9EDF1));
            },
            itemBuilder: (context, index) {
              final document = orders[index];
              final data = document.data();

              return _TrackingListItem(
                orderId: document.id,
                data: data,
                admin: admin,
                toDouble: _toDouble,
                statusTextColor: _statusTextColor,
                statusBackgroundColor: _statusBackgroundColor,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessage({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 42),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TrackingListItem extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final AdminViewModel admin;
  final double? Function(dynamic value) toDouble;
  final Color Function(String status) statusTextColor;
  final Color Function(String status) statusBackgroundColor;

  const _TrackingListItem({
    required this.orderId,
    required this.data,
    required this.admin,
    required this.toDouble,
    required this.statusTextColor,
    required this.statusBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final String driverId = data['driver_id']?.toString() ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: driverId.isEmpty
          ? null
          : FirebaseFirestore.instance
                .collection('driver_locations')
                .doc(driverId)
                .snapshots(),
      builder: (context, locationSnapshot) {
        final driverLocation = locationSnapshot.data?.data() ?? {};

        final double? driverLat = toDouble(
          driverLocation['latitude'] ??
              driverLocation['lat'] ??
              data['driver_lat'],
        );

        final double? driverLng = toDouble(
          driverLocation['longitude'] ??
              driverLocation['lng'] ??
              data['driver_lng'],
        );

        final double? pickupLat = toDouble(data['pickup_lat']);

        final double? pickupLng = toDouble(data['pickup_lng']);

        final double? destinationLat = toDouble(
          data['dest_lat'] ?? data['destination_lat'],
        );

        final double? destinationLng = toDouble(
          data['dest_lng'] ?? data['destination_lng'],
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

        final String status = data['status']?.toString() ?? '';

        final String item =
            data['item_description']?.toString().trim().isNotEmpty == true
            ? data['item_description'].toString().trim()
            : 'Paket';

        final String shortId = orderId.length > 8
            ? orderId.substring(0, 8).toUpperCase()
            : orderId.toUpperCase();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminTrackingDetailScreen(orderId: orderId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 145,
                    height: 104,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0F5),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: IgnorePointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
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
                                  strokeWidth: 4,
                                  color: const Color(0xFF3C86D1),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (hasPickup)
                                Marker(
                                  point: LatLng(pickupLat, pickupLng),
                                  width: 34,
                                  height: 34,
                                  child: const _MiniMarker(
                                    color: Color(0xFF20B86B),
                                    icon: Icons.location_on_rounded,
                                  ),
                                ),
                              if (hasDriver)
                                Marker(
                                  point: LatLng(driverLat, driverLng),
                                  width: 38,
                                  height: 38,
                                  child: const _MiniMarker(
                                    color: Color(0xFF133D87),
                                    icon: Icons.delivery_dining_rounded,
                                  ),
                                ),
                              if (hasDestination)
                                Marker(
                                  point: LatLng(destinationLat, destinationLng),
                                  width: 36,
                                  height: 36,
                                  child: const _MiniMarker(
                                    color: Color(0xFFE85B5B),
                                    icon: Icons.location_on_rounded,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#ORD-$shortId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF202832),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF858E99),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBackgroundColor(status),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Text(
                                  admin.statusLabel(status),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: statusTextColor(status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              admin.formatTime(data['created_at']),
                              style: GoogleFonts.inter(
                                color: const Color(0xFF858E99),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFAAB3BC),
                    size: 27,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: 51,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF5FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5279A7)
                  : const Color(0xFFE5E9EE),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected
                  ? const Color(0xFF224A7A)
                  : const Color(0xFF737C87),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MiniMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 5),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}
