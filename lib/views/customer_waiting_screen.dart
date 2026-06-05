import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/customer_order_viewmodel.dart';
import 'map_driver_screen.dart';

class CustomerWaitingScreen extends StatefulWidget {
  final String orderId;

  const CustomerWaitingScreen({super.key, required this.orderId});

  @override
  State<CustomerWaitingScreen> createState() => _CustomerWaitingScreenState();
}

class _CustomerWaitingScreenState extends State<CustomerWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final CustomerOrderViewModel _viewModel;
  late final AnimationController _radarController;
  bool _handledNavigation = false;

  @override
  void initState() {
    super.initState();
    _viewModel = CustomerOrderViewModel(orderId: widget.orderId);
    _viewModel.addListener(_handleViewModelUpdate);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelUpdate);
    _viewModel.dispose();
    _radarController.dispose();
    super.dispose();
  }

  void _handleViewModelUpdate() {
    if (!mounted || _handledNavigation) {
      return;
    }

    final state = _viewModel.state;

    if (state == CustomerOrderFlowState.driverAssigned) {
      _handledNavigation = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MapDriverScreen(orderId: widget.orderId),
        ),
      );
      return;
    }

    if (state == CustomerOrderFlowState.timeout ||
        state == CustomerOrderFlowState.cancelled) {
      _handledNavigation = true;
      final messenger = ScaffoldMessenger.of(context);
      final message = state == CustomerOrderFlowState.timeout
          ? 'Pesanan dibatalkan otomatis karena tidak ada driver.'
          : 'Pesanan berhasil dibatalkan.';

      messenger.showSnackBar(SnackBar(content: Text(message)));

      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _cancelOrder() async {
    await _viewModel.cancelOrder();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CustomerOrderViewModel>.value(
      value: _viewModel,
      child: Consumer<CustomerOrderViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF07111F),
                    Color(0xFF0D1B2A),
                    Color(0xFF111827),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_ios_new),
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Menunggu Driver',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = constraints.maxWidth < 320
                                  ? constraints.maxWidth * 0.9
                                  : 320.0;

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _RadarSearchAnimation(
                                    controller: _radarController,
                                    size: size,
                                  ),
                                  const SizedBox(height: 32),
                                  const Text(
                                    'Searching for nearby drivers...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    viewModel.message ??
                                        'Tunggu sebentar, driver terbaik sedang dicari.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: viewModel.canCancel
                                        ? Container(
                                            key: const ValueKey(
                                              'cancel-countdown',
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Batalkan otomatis tersedia',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${viewModel.cancelCountdown} detik',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 250),
                        offset: viewModel.canCancel
                            ? Offset.zero
                            : const Offset(0, 0.2),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: viewModel.canCancel ? 1 : 0,
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: viewModel.canCancel
                                  ? _cancelOrder
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE76F51),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFE76F51,
                                ).withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text(
                                'Batalkan Pesanan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadarSearchAnimation extends StatelessWidget {
  const _RadarSearchAnimation({required this.controller, required this.size});

  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6EE7F9).withValues(alpha: 0.16),
                      const Color(0xFF0F172A).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              for (final ripple in [0.0, 0.33, 0.66])
                _RadarRipple(progress: (progress + ripple) % 1.0),
              Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF8BE9FD), Color(0xFF1D4ED8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.45),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.radar, color: Colors.white, size: 42),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RadarRipple extends StatelessWidget {
  const _RadarRipple({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final scale = 0.45 + (eased * 0.55);
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.35;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF67E8F9).withValues(alpha: 0.95),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
