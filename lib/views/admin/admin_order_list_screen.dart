import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_bottom_bar.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF202832);
  static const Color _textGrey = Color(0xFF7A8594);
  static const Color _lightGrey = Color(0xFFF4F7FA);
  static const Color _borderColor = Color(0xFFD9E4F2);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFD39A22);

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFF3B82F6);

      case 'completed':
        return const Color(0xFF22B36A);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFE26868);

      default:
        return _textGrey;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFF5DB);

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFFEAF2FF);

      case 'completed':
        return const Color(0xFFE4FAEC);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFFFE8EA);

      default:
        return const Color(0xFFF1F4F8);
    }
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
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
                        children: [
                          _buildTopHeader(),
                          const SizedBox(height: 30),
                          _buildSearchField(admin),
                          const SizedBox(height: 22),
                          _buildFilterList(admin),
                          const SizedBox(height: 20),
                          _buildOrderList(admin),
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
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 2),
    );
  }

  Widget _buildTopHeader() {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              'Orders',
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
              onPressed: _focusSearch,
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

  Widget _buildSearchField(AdminViewModel admin) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (value) {
        admin.changeOrderSearchQuery(value);
        setState(() {});
      },
      style: GoogleFonts.inter(color: _textDark, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search order, item, or address...',
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFFB2BAC6),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 15, right: 10),
          child: Icon(Icons.search_rounded, color: Color(0xFF95A1AE), size: 25),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  admin.changeOrderSearchQuery('');

                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, color: _textGrey),
              ),
        filled: true,
        fillColor: _lightGrey,
        contentPadding: const EdgeInsets.symmetric(vertical: 19),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _titleBlue, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildFilterList(AdminViewModel admin) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _OrderFilterChip(
            label: 'All',
            selected: admin.selectedOrderStatus == 'all',
            onTap: () {
              admin.changeOrderStatus('all');
            },
          ),
          _OrderFilterChip(
            label: 'Pending',
            selected: admin.selectedOrderStatus == 'pending',
            onTap: () {
              admin.changeOrderStatus('pending');
            },
          ),
          _OrderFilterChip(
            label: 'On Delivery',
            selected: admin.selectedOrderStatus == 'onDelivery',
            onTap: () {
              admin.changeOrderStatus('onDelivery');
            },
          ),
          _OrderFilterChip(
            label: 'Completed',
            selected: admin.selectedOrderStatus == 'completed',
            onTap: () {
              admin.changeOrderStatus('completed');
            },
          ),
          _OrderFilterChip(
            label: 'Cancel',
            selected: admin.selectedOrderStatus == 'cancelled',
            onTap: () {
              admin.changeOrderStatus('cancelled');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessageCard(
            icon: Icons.error_outline_rounded,
            text: 'Gagal memuat order.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(36),
            child: Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders =
            (snapshot.data?.docs ?? []).where((document) {
              final Map<String, dynamic> data = document.data();

              final String status = data['status']?.toString() ?? '';

              return admin.isOrderMatchStatus(status) &&
                  admin.isOrderMatchSearch(document.id, data);
            }).toList();

        if (orders.isEmpty) {
          return _buildMessageCard(
            icon: Icons.inventory_2_outlined,
            text: 'Order tidak ditemukan.',
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) {
              return Divider(
                height: 18,
                thickness: 1,
                color: Colors.grey.withValues(alpha: 0.16),
              );
            },
            itemBuilder: (context, index) {
              final document = orders[index];

              final Map<String, dynamic> data = document.data();

              final String status = data['status']?.toString() ?? '';

              final String itemName =
                  data['item_description']?.toString().trim().isNotEmpty == true
                  ? data['item_description'].toString().trim()
                  : 'Paket';

              final String pickupAddress =
                  data['pickup_address']?.toString().trim().isNotEmpty == true
                  ? data['pickup_address'].toString().trim()
                  : '-';

              final String destinationAddress =
                  (data['dest_address'] ?? data['destination_address'])
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? (data['dest_address'] ?? data['destination_address'])
                        .toString()
                        .trim()
                  : '-';

              final dynamic totalCost =
                  data['total_cost'] ??
                  data['shipping_cost'] ??
                  data['price'] ??
                  0;

              final String shortId = document.id.length > 8
                  ? document.id.substring(0, 8).toUpperCase()
                  : document.id.toUpperCase();

              return _buildOrderItem(
                context: context,
                orderId: document.id,
                shortId: shortId,
                itemName: itemName,
                pickupAddress: pickupAddress,
                destinationAddress: destinationAddress,
                status: status,
                statusLabel: admin.statusLabel(status),
                totalCost: admin.formatCurrency(totalCost),
                date: admin.formatDate(data['created_at']),
                time: admin.formatTime(data['created_at']),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderItem({
    required BuildContext context,
    required String orderId,
    required String shortId,
    required String itemName,
    required String pickupAddress,
    required String destinationAddress,
    required String status,
    required String statusLabel,
    required String totalCost,
    required String date,
    required String time,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailScreen(orderId: orderId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _primaryBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '#ORD-$shortId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBackgroundColor(status),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              color: _statusTextColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.trip_origin_rounded,
                            color: Color(0xFF22B36A),
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            pickupAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFE25C5C),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            destinationAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: _primaryBlue,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            totalCost,
                            style: GoogleFonts.inter(
                              color: _primaryBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFACB5C1),
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        date,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB0B8C3),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 42),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _OrderFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEFF5FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF7597C4)
                    : const Color(0xFFE5EAF1),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? const []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: selected
                    ? const Color(0xFF1E4D8F)
                    : const Color(0xFF6B7380),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
