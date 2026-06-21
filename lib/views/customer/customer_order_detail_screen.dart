import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../utils/app_assets.dart';
import 'customer_tracking_screen.dart';
import 'rating_screen.dart';

class CustomerOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const CustomerOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState
    extends State<CustomerOrderDetailScreen> {
  final OrderService _orderService = OrderService();

  String? _cachedDriverId;
  Future<Map<String, dynamic>?>? _driverProfileFuture;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _successGreen = Color(0xFF0AAA55);

  Future<Map<String, dynamic>?>? _getDriverProfile(
    String? driverId,
  ) {
    if (driverId == null || driverId.trim().isEmpty) {
      return null;
    }

    if (_cachedDriverId != driverId ||
        _driverProfileFuture == null) {
      _cachedDriverId = driverId;

      _driverProfileFuture =
          _orderService.fetchDriverProfile(driverId);
    }

    return _driverProfileFuture;
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

    final String day =
        date.day.toString().padLeft(2, '0');

    final String hour =
        date.hour.toString().padLeft(2, '0');

    final String minute =
        date.minute.toString().padLeft(2, '0');

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
        return 'Waiting Driver';

      case OrderStatus.accepted:
        return 'Driver Accepted';

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

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFE08B00);

      case OrderStatus.accepted:
      case OrderStatus.pickingUp:
      case OrderStatus.delivering:
        return const Color(0xFF0066FF);

      case OrderStatus.completed:
        return _successGreen;

      case OrderStatus.cancelled:
        return const Color(0xFFD14343);
    }
  }

  bool _isActiveOrder(OrderStatus status) {
    return status == OrderStatus.accepted ||
        status == OrderStatus.pickingUp ||
        status == OrderStatus.delivering;
  }

  void _openTracking(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerTrackingScreen(
          orderId: order.orderId,
        ),
      ),
    );
  }

  void _openRating(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          order: order,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<OrderModel?>(
        stream: _orderService.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(
              'Gagal memuat detail order.',
            );
          }

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: _primaryBlue,
              ),
            );
          }

          final OrderModel? order = snapshot.data;

          if (order == null) {
            return _buildErrorState(
              'Order tidak ditemukan.',
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                AppAssets.loginBackground,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const ColoredBox(
                    color: Color(0xFFF7F9FC),
                  );
                },
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    SvgPicture.asset(
                      AppAssets.logo,
                      width: 214,
                    ),
                    const SizedBox(height: 26),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _buildContent(order),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    final String itemName =
        order.itemDescription.trim().isNotEmpty
            ? order.itemDescription.trim()
            : 'Paket';

    final String weightName =
        order.weightCategoryName.trim().isNotEmpty
            ? order.weightCategoryName.trim()
            : order.weightCategoryId ?? '-';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        34,
      ),
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildStatusCard(order),
        const SizedBox(height: 18),
        _buildDriverCard(order),
        const SizedBox(height: 18),
        _buildAddressCard(order),
        const SizedBox(height: 18),
        _buildItemCard(
          order: order,
          itemName: itemName,
          weightName: weightName,
        ),
        const SizedBox(height: 18),
        _buildPaymentCard(order),
        const SizedBox(height: 25),
        _buildActionButton(order),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
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
            'Order Detail',
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont(
              'ADLaM Display',
              color: _titleBlue,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildStatusCard(OrderModel order) {
    final Color statusColor =
        _statusColor(order.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              order.status == OrderStatus.completed
                  ? Icons.check_circle_outline_rounded
                  : order.status == OrderStatus.cancelled
                      ? Icons.cancel_outlined
                      : Icons.local_shipping_outlined,
              color: statusColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(order.status),
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDisplayOrderId(
                    order.orderId,
                  ),
                  style: GoogleFonts.inter(
                    color: _textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(
              order.updatedAt ?? order.createdAt,
            ),
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(OrderModel order) {
    final Future<Map<String, dynamic>?>? driverFuture =
        _getDriverProfile(order.driverId);

    return _DetailSection(
      title: 'Driver',
      child: driverFuture == null
          ? _buildDriverInformation(
              name: 'Belum Ada Driver',
              photoUrl: '',
              rating: 0,
              ratingCount: 0,
            )
          : FutureBuilder<Map<String, dynamic>?>(
              future: driverFuture,
              builder: (context, snapshot) {
                final Map<String, dynamic>? data =
                    snapshot.data;

                return _buildDriverInformation(
                  name:
                      data?['name'] as String? ?? 'Driver',
                  photoUrl:
                      data?['photo_url'] as String? ?? '',
                  rating:
                      (data?['rating_avg'] as num?)
                              ?.toDouble() ??
                          0,
                  ratingCount:
                      (data?['rating_count'] as num?)
                              ?.toInt() ??
                          0,
                );
              },
            ),
    );
  }

  Widget _buildDriverInformation({
    required String name,
    required String photoUrl,
    required double rating,
    required int ratingCount,
  }) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _titleBlue.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: photoUrl.trim().isEmpty
              ? const Icon(
                  Icons.person_rounded,
                  color: _primaryBlue,
                  size: 31,
                )
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.person_rounded,
                      color: _primaryBlue,
                      size: 31,
                    );
                  },
                ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name,
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
                    rating > 0
                        ? rating.toStringAsFixed(1)
                        : '-',
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
      ],
    );
  }

  Widget _buildAddressCard(OrderModel order) {
    return _DetailSection(
      title: 'Delivery Address',
      child: Column(
        children: [
          _AddressRow(
            title: 'Pickup',
            address: order.pickupAddress,
            color: const Color(0xFF0066FF),
            icon: Icons.radio_button_checked_rounded,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 22,
                child: VerticalDivider(
                  width: 2,
                  thickness: 1.5,
                  color: Color(0xFFCAD4E1),
                ),
              ),
            ),
          ),
          _AddressRow(
            title: 'Destination',
            address: order.destinationAddress,
            color: _successGreen,
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required OrderModel order,
    required String itemName,
    required String weightName,
  }) {
    return _DetailSection(
      title: 'Item Information',
      child: Column(
        children: [
          _DetailRow(
            label: 'Item',
            value: itemName,
          ),
          const SizedBox(height: 11),
          _DetailRow(
            label: 'Weight',
            value: weightName,
          ),
          const SizedBox(height: 11),
          _DetailRow(
            label: 'Distance',
            value:
                '${order.distanceKm.toStringAsFixed(2)} km',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    return _DetailSection(
      title: 'Payment Details',
      child: Column(
        children: [
          const _DetailRow(
            label: 'Payment Method',
            value: 'Cash',
          ),
          const SizedBox(height: 11),
          _DetailRow(
            label: 'Delivery Fee',
            value: _formatCurrency(order.totalCost),
          ),
          const Divider(
            height: 25,
            color: Color(0xFFE3E8EF),
          ),
          _DetailRow(
            label: 'Total Payment',
            value: _formatCurrency(order.totalCost),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(OrderModel order) {
    if (_isActiveOrder(order.status)) {
      return SizedBox(
        width: double.infinity,
        height: 51,
        child: ElevatedButton.icon(
          onPressed: () => _openTracking(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(
            Icons.location_searching_rounded,
            size: 20,
          ),
          label: Text(
            'Track Order',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (order.status == OrderStatus.completed &&
        order.rating == null) {
      return SizedBox(
        width: double.infinity,
        height: 51,
        child: ElevatedButton.icon(
          onPressed: () => _openRating(order),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(
            Icons.star_outline_rounded,
            size: 21,
          ),
          label: Text(
            'Give Rating',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (order.status == OrderStatus.completed &&
        order.rating != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: _successGreen.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _successGreen.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFB800),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Your Rating: ${order.rating}/5',
              style: GoogleFonts.inter(
                color: _successGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorState(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFD14343),
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 14,
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
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFC5D8EE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1D23),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(
            height: 24,
            color: Color(0xFFE3E8EF),
          ),
          child,
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final String title;
  final String address;
  final Color color;
  final IconData icon;

  const _AddressRow({
    required this.title,
    required this.address,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  color: const Color(0xFF6F7784),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF6F7784),
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1D23),
              fontSize: bold ? 14 : 12.5,
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}