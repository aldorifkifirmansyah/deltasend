import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../utils/app_assets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'customer_order_detail_screen.dart';

enum _OrderFilter { all, active, completed, cancelled }

class CustomerOrderHistoryScreen extends StatefulWidget {
  const CustomerOrderHistoryScreen({super.key});

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<OrderModel>> _orderStream;

  _OrderFilter _selectedFilter = _OrderFilter.all;
  String _searchQuery = '';

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);

  @override
  void initState() {
    super.initState();

    final String customerId =
        context.read<AuthViewModel>().currentUser?.uid ?? '';

    _orderStream = _orderService.watchCustomerOrders(customerId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    Iterable<OrderModel> filteredOrders = orders;

    switch (_selectedFilter) {
      case _OrderFilter.all:
        break;

      case _OrderFilter.active:
        filteredOrders = filteredOrders.where(
          (order) =>
              order.status == OrderStatus.pending ||
              order.status == OrderStatus.accepted ||
              order.status == OrderStatus.pickingUp ||
              order.status == OrderStatus.delivering,
        );
        break;

      case _OrderFilter.completed:
        filteredOrders = filteredOrders.where(
          (order) => order.status == OrderStatus.completed,
        );
        break;

      case _OrderFilter.cancelled:
        filteredOrders = filteredOrders.where(
          (order) => order.status == OrderStatus.cancelled,
        );
        break;
    }

    final String query = _searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        return order.orderId.toLowerCase().contains(query) ||
            order.itemDescription.toLowerCase().contains(query) ||
            order.pickupAddress.toLowerCase().contains(query) ||
            order.destinationAddress.toLowerCase().contains(query);
      });
    }

    return filteredOrders.toList();
  }

  String _formatDisplayOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortId';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    const List<String> monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final String day = date.day.toString().padLeft(2, '0');

    final String hour = date.hour.toString().padLeft(2, '0');

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day ${monthNames[date.month - 1]} '
        '${date.year}, $hour:$minute';
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

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting';

      case OrderStatus.accepted:
        return 'Accepted';

      case OrderStatus.pickingUp:
        return 'Picking Up';

      case OrderStatus.delivering:
        return 'On Delivery';

      case OrderStatus.completed:
        return 'Completed';

      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusTextColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFE08B00);

      case OrderStatus.accepted:
      case OrderStatus.pickingUp:
      case OrderStatus.delivering:
        return const Color(0xFF0066FF);

      case OrderStatus.completed:
        return const Color(0xFF0AAA55);

      case OrderStatus.cancelled:
        return const Color(0xFFD14343);
    }
  }

  Color _statusBackgroundColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFFF3D8);

      case OrderStatus.accepted:
      case OrderStatus.pickingUp:
      case OrderStatus.delivering:
        return const Color(0xFFE7F0FF);

      case OrderStatus.completed:
        return const Color(0xFFE1F8EB);

      case OrderStatus.cancelled:
        return const Color(0xFFFFE8E8);
    }
  }

  void _openOrderDetail(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerOrderDetailScreen(orderId: order.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return const ColoredBox(color: Color(0xFFF7F9FC));
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                SvgPicture.asset(AppAssets.logo, width: 214),
                const SizedBox(height: 26),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildSearchField(),
                        _buildFilterSection(),
                        Expanded(child: _buildOrderList()),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
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
              'Orders',
              textAlign: TextAlign.center,
              style: GoogleFonts.getFont(
                'ADLaM Display',
                color: _titleBlue,
                fontSize: 23,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.inter(color: _textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search your order',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF9DA7B5),
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _titleBlue,
            size: 23,
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
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          _FilterButton(
            label: 'All',
            selected: _selectedFilter == _OrderFilter.all,
            onTap: () {
              setState(() {
                _selectedFilter = _OrderFilter.all;
              });
            },
          ),
          const SizedBox(width: 9),
          _FilterButton(
            label: 'On Delivery',
            selected: _selectedFilter == _OrderFilter.active,
            onTap: () {
              setState(() {
                _selectedFilter = _OrderFilter.active;
              });
            },
          ),
          const SizedBox(width: 9),
          _FilterButton(
            label: 'Completed',
            selected: _selectedFilter == _OrderFilter.completed,
            onTap: () {
              setState(() {
                _selectedFilter = _OrderFilter.completed;
              });
            },
          ),
          const SizedBox(width: 9),
          _FilterButton(
            label: 'Cancel',
            selected: _selectedFilter == _OrderFilter.cancelled,
            onTap: () {
              setState(() {
                _selectedFilter = _OrderFilter.cancelled;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Gagal memuat riwayat order.');
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        }

        final List<OrderModel> allOrders = snapshot.data ?? [];

        final List<OrderModel> orders = _filterOrders(allOrders);

        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
          itemCount: orders.length,
          separatorBuilder: (_, __) {
            return const SizedBox(height: 13);
          },
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index]);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final String itemName = order.itemDescription.trim().isNotEmpty
        ? order.itemDescription.trim()
        : 'Paket';

    final Color statusColor = _statusTextColor(order.status);

    final Color statusBackground = _statusBackgroundColor(order.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOrderDetail(order),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
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
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 47,
                    height: 47,
                    decoration: BoxDecoration(
                      color: _titleBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: _primaryBlue,
                      size: 26,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatDisplayOrderId(order.orderId),
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _statusLabel(order.status),
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 25, color: Color(0xFFE4E9F0)),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: _titleBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.destinationAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Text(
                    _formatDate(order.updatedAt ?? order.createdAt),
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 11.5),
                  ),
                  const Spacer(),
                  Text(
                    _formatCurrency(order.totalCost),
                    style: GoogleFonts.inter(
                      color: _textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _titleBlue,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _titleBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _primaryBlue,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Order',
              style: GoogleFonts.getFont(
                'ADLaM Display',
                color: _titleBlue,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order yang sesuai dengan filter akan ditampilkan di sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textGrey,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD14343),
              size: 50,
            ),
            const SizedBox(height: 13),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textGrey, fontSize: 14),
            ),
          ],
        ),
      ),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF133D87) : const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF133D87)
                  : const Color(0xFFDCE4EF),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : const Color(0xFF6F7784),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
