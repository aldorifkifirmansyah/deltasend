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

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1B1B1B);
  static const Color _textGrey = Color(0xFF687386);
  static const Color _borderBlue = Color(0xFFC9D9ED);
  static const Color _pageBackground = Color(0xFFF8FAFD);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFE08B00);

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFF0066FF);

      case 'completed':
        return const Color(0xFF0AAA55);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFD14343);

      default:
        return _textGrey;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFF3D8);

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFFE7F0FF);

      case 'completed':
        return const Color(0xFFE2F9EB);

      case 'cancelled':
      case 'cancel':
        return const Color(0xFFFFE8E8);

      default:
        return const Color(0xFFF0F2F5);
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
                const SizedBox(height: 18),
                SvgPicture.asset(AppAssets.logo, width: 215),
                const SizedBox(height: 24),
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 120),
                        children: [
                          Text(
                            'Orders',
                            style: GoogleFonts.getFont(
                              'ADLaM Display',
                              color: _titleBlue,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Pantau seluruh order DeltaSend.',
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildSearchField(admin),
                          const SizedBox(height: 16),
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

  Widget _buildSearchField(AdminViewModel admin) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        admin.changeOrderSearchQuery(value);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Cari order, alamat, atau barang',
        hintStyle: GoogleFonts.inter(color: _textGrey, fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: _titleBlue),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  admin.changeOrderSearchQuery('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
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

        return Column(
          children: orders.map((document) {
            final Map<String, dynamic> data = document.data();

            final String itemName =
                data['item_description']?.toString().trim().isNotEmpty == true
                ? data['item_description'].toString().trim()
                : 'Paket';

            final String pickupAddress =
                data['pickup_address']?.toString() ?? '-';

            final String destinationAddress =
                (data['dest_address'] ?? data['destination_address'] ?? '-')
                    .toString();

            final String status = data['status']?.toString() ?? '';

            final dynamic totalCost =
                data['total_cost'] ??
                data['shipping_cost'] ??
                data['price'] ??
                0;

            final String shortId = document.id.length > 8
                ? document.id.substring(0, 8).toUpperCase()
                : document.id.toUpperCase();

            return _buildOrderCard(
              orderId: document.id,
              shortId: shortId,
              itemName: itemName,
              pickupAddress: pickupAddress,
              destinationAddress: destinationAddress,
              status: status,
              totalCost: admin.formatCurrency(totalCost),
              date: admin.formatDate(data['created_at']),
              time: admin.formatTime(data['created_at']),
              statusLabel: admin.statusLabel(status),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOrderCard({
    required String orderId,
    required String shortId,
    required String itemName,
    required String pickupAddress,
    required String destinationAddress,
    required String status,
    required String totalCost,
    required String date,
    required String time,
    required String statusLabel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: _titleBlue.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
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
                            itemName,
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
                            '#ORD-$shortId',
                            style: GoogleFonts.inter(
                              color: _textGrey,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBackground(status),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          color: _statusColor(status),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trip_origin_rounded,
                      color: Color(0xFF0AAA55),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFFF4A45),
                      size: 16,
                    ),
                    const SizedBox(width: 7),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      totalCost,
                      style: GoogleFonts.inter(
                        color: _primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$date • $time',
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _titleBlue,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: [
          Icon(icon, color: _titleBlue, size: 40),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.only(right: 9),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          onTap();
        },
        showCheckmark: false,
        selectedColor: const Color(0xFF133D87),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF133D87)),
        labelStyle: GoogleFonts.inter(
          color: selected ? Colors.white : const Color(0xFF133D87),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
