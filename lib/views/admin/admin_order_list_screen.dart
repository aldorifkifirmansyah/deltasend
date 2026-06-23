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

  static const Color _textDark = Color(0xFF1A1D23);

  static const Color _textGrey = Color(0xFF687386);

  static const Color _pageBackground = Color(0xFFF7F9FC);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openOrderDetail(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailScreen(orderId: orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminViewModel admin = context.watch<AdminViewModel>();

    return Scaffold(
      backgroundColor: _pageBackground,
      bottomNavigationBar: const AdminBottomBar(selectedIndex: 2),
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
                          Expanded(child: _buildOrderStream(admin)),
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
              'Orders',
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
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 10),
        children: [
          _buildFilterButton(admin: admin, label: 'All', value: 'all'),
          const SizedBox(width: 10),
          _buildFilterButton(
            admin: admin,
            label: 'On Delivery',
            value: 'onDelivery',
          ),
          const SizedBox(width: 10),
          _buildFilterButton(
            admin: admin,
            label: 'Completed',
            value: 'completed',
          ),
          const SizedBox(width: 10),
          _buildFilterButton(admin: admin, label: 'Cancel', value: 'cancelled'),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? _primaryBlue : _textGrey,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderStream(AdminViewModel admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.watchOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildStateMessage(
            icon: Icons.error_outline_rounded,
            title: 'Gagal memuat order',
            description: 'Periksa koneksi atau konfigurasi Firebase.',
            error: true,
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders =
            snapshot.data!.docs.where((document) {
              final Map<String, dynamic> data = document.data();

              final String status = data['status']?.toString() ?? '';

              return admin.isOrderMatchStatus(status) &&
                  admin.isOrderMatchSearch(document.id, data);
            }).toList();

        if (orders.isEmpty) {
          return _buildStateMessage(
            icon: Icons.receipt_long_outlined,
            title: 'Order tidak ditemukan',
            description: 'Tidak ada order yang sesuai dengan filter.',
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9),
            itemCount: orders.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFEDF0F4)),
            itemBuilder: (context, index) {
              final document = orders[index];

              return _buildOrderItem(
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

  Widget _buildOrderItem({
    required AdminViewModel admin,
    required String orderId,
    required Map<String, dynamic> data,
  }) {
    final String status = data['status']?.toString() ?? 'pending';

    final String itemDescription =
        data['item_description']?.toString().trim() ?? '';

    final String pickupAddress =
        data['pickup_address']?.toString().trim() ?? '';

    final String destinationAddress =
        (data['dest_address'] ?? data['destination_address'])
            ?.toString()
            .trim() ??
        '';

    final dynamic totalCost = data['total_cost'] ?? data['totalCost'] ?? 0;

    final String subtitle = itemDescription.isNotEmpty
        ? itemDescription
        : destinationAddress.isNotEmpty
        ? destinationAddress
        : pickupAddress.isNotEmpty
        ? pickupAddress
        : 'Paket';

    final String time = admin.formatTime(data['created_at']);

    final String price = admin.formatCurrency(totalCost);

    final Color statusColor = _statusColor(status);

    final Color statusBackground = _statusBackground(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOrderDetail(orderId),
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _titleBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
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
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: _primaryBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: _primaryBlue,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _primaryBlue,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 88),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      admin.statusLabel(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 31),
                  Text(
                    time,
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(width: 3),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA6B0BC),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String description,
    bool error = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: error ? const Color(0xFFD14343) : _titleBlue,
              size: 46,
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 14.5,
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

  String _formatOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

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

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFF0066FF);

      default:
        return _textGrey;
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

      case 'accepted':
      case 'pickingUp':
      case 'delivering':
      case 'onDelivery':
        return const Color(0xFFE7F0FF);

      default:
        return const Color(0xFFF0F2F5);
    }
  }
}
