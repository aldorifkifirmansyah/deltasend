import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../utils/app_assets.dart';
import '../../viewmodels/customer_order_viewmodel.dart';
import 'customer_tracking_screen.dart';

class CustomerWaitingScreen extends StatefulWidget {
  final String orderId;

  const CustomerWaitingScreen({super.key, required this.orderId});

  @override
  State<CustomerWaitingScreen> createState() => _CustomerWaitingScreenState();
}

class _CustomerWaitingScreenState extends State<CustomerWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final CustomerOrderViewModel _viewModel;
  late final AnimationController _loadingController;

  bool _handledNavigation = false;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _pickupBlue = Color(0xFF0066FF);
  static const Color _destinationGreen = Color(0xFF0AAA55);
  static const Color _dangerRed = Color(0xFFD14343);

  @override
  void initState() {
    super.initState();

    _viewModel = CustomerOrderViewModel(orderId: widget.orderId);

    _viewModel.addListener(_handleViewModelUpdate);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelUpdate);
    _viewModel.dispose();
    _loadingController.dispose();

    super.dispose();
  }

  void _handleViewModelUpdate() {
    if (!mounted || _handledNavigation) {
      return;
    }

    final CustomerOrderFlowState state = _viewModel.state;

    if (state == CustomerOrderFlowState.driverAssigned) {
      _handledNavigation = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerTrackingScreen(orderId: widget.orderId),
        ),
      );

      return;
    }

    if (state == CustomerOrderFlowState.timeout ||
        state == CustomerOrderFlowState.cancelled) {
      _handledNavigation = true;

      final String message = state == CustomerOrderFlowState.timeout
          ? 'Order dibatalkan karena tidak ada driver yang menerima.'
          : 'Order berhasil dibatalkan.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    if (state == CustomerOrderFlowState.error) {
      final String message = _viewModel.message ?? 'Gagal memantau order.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Batalkan order?',
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Order yang dibatalkan tidak dapat diproses kembali.',
            style: GoogleFonts.inter(
              color: _textGrey,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Kembali',
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Batalkan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _viewModel.cancelOrder();
  }

  String _formatCurrency(double value) {
    final String raw = value.toStringAsFixed(0);
    final StringBuffer result = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final int remaining = raw.length - i;

      result.write(raw[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        result.write('.');
      }
    }

    return 'Rp. $result';
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CustomerOrderViewModel>.value(
      value: _viewModel,
      child: Consumer<CustomerOrderViewModel>(
        builder: (context, viewModel, _) {
          final OrderModel? order = viewModel.currentOrder;

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
                          child: order == null
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
                                )
                              : _buildContent(order, viewModel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(OrderModel order, CustomerOrderViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
      children: [
        _buildHeader(),
        const SizedBox(height: 22),
        _buildOrderSummary(order),
        const SizedBox(height: 20),
        _buildPaymentCard(order),
        const SizedBox(height: 24),
        _buildSearchingDriverPanel(viewModel),
        const SizedBox(height: 20),
        _buildTimeoutInformation(viewModel),
        const SizedBox(height: 22),
        _buildCancelButton(viewModel),
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
            'Konfirmasi Order',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildOrderSummary(OrderModel order) {
    final String itemDescription = order.itemDescription.trim().isNotEmpty
        ? order.itemDescription.trim()
        : 'Paket';

    final String weightLabel = order.weightCategoryName.trim().isNotEmpty
        ? order.weightCategoryName.trim()
        : order.weightCategoryId ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Detail Order',
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatOrderId(order.orderId),
                style: GoogleFonts.inter(
                  color: _titleBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AddressInformation(
            label: 'Pickup',
            address: order.pickupAddress,
            color: _pickupBlue,
            icon: Icons.radio_button_checked_rounded,
          ),
          const SizedBox(height: 14),
          _AddressInformation(
            label: 'Tujuan',
            address: order.destinationAddress,
            color: _destinationGreen,
            icon: Icons.location_on_rounded,
          ),
          const Divider(height: 28, color: Color(0xFFE5E9EF)),
          _SummaryValueRow(label: 'Barang', value: itemDescription),
          const SizedBox(height: 11),
          _SummaryValueRow(label: 'Kategori Berat', value: weightLabel),
          const SizedBox(height: 11),
          _SummaryValueRow(
            label: 'Jarak',
            value: '${order.distanceKm.toStringAsFixed(2)} km',
          ),
          const SizedBox(height: 11),
          _SummaryValueRow(
            label: 'Ongkir',
            value: _formatCurrency(order.totalCost),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5F1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: _primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Metode Pembayaran',
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Tunai',
                style: GoogleFonts.inter(
                  color: _textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: Color(0xFFE2E7ED)),
          Row(
            children: [
              Text(
                'Total Pembayaran',
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatCurrency(order.totalCost),
                style: GoogleFonts.inter(
                  color: _primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingDriverPanel(CustomerOrderViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          _SearchingAnimation(controller: _loadingController),
          const SizedBox(height: 18),
          Text(
            'Mencari Driver Terdekat',
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont(
              'ADLaM Display',
              color: Colors.white,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.message ??
                'Mohon tunggu, kami sedang mencari driver yang tersedia di sekitar lokasi pickup.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _AnimatedLoadingDots(controller: _loadingController),
        ],
      ),
    );
  }

  Widget _buildTimeoutInformation(CustomerOrderViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDCE4EF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: _titleBlue, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              viewModel.systemCountdown > 0
                  ? 'Pencarian otomatis berakhir dalam ${viewModel.systemCountdown} detik.'
                  : 'Pencarian sedang diselesaikan.',
              style: GoogleFonts.inter(
                color: _textGrey,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(CustomerOrderViewModel viewModel) {
    final bool canCancel = viewModel.canCancel;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: canCancel ? _cancelOrder : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _dangerRed,
              disabledForegroundColor: const Color(0xFFB6BDC7),
              side: BorderSide(
                color: canCancel ? _dangerRed : const Color(0xFFD6DCE5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: Text(
              canCancel ? 'BATALKAN PESANAN' : 'PEMBATALAN TIDAK TERSEDIA',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        if (canCancel) ...[
          const SizedBox(height: 8),
          Text(
            'Pembatalan tersedia selama ${viewModel.buttonCountdown} detik.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _textGrey, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _AddressInformation extends StatelessWidget {
  final String label;
  final String address;
  final Color color;
  final IconData icon;

  const _AddressInformation({
    required this.label,
    required this.address,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  color: const Color(0xFF6F7784),
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
}

class _SummaryValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1D23),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchingAnimation extends StatelessWidget {
  final AnimationController controller;

  const _SearchingAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.75 + (controller.value * 0.25),
                child: Opacity(
                  opacity: 1 - controller.value,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.6 + (((controller.value + 0.45) % 1) * 0.4),
                child: Opacity(
                  opacity: 1 - ((controller.value + 0.45) % 1),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Color(0xFF133D87),
                  size: 35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedLoadingDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedLoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double shifted = (controller.value - (index * 0.20)) % 1;

            final double opacity = 0.30 + (shifted * 0.70);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
