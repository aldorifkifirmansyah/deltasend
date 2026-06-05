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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ChangeNotifierProvider<CustomerOrderViewModel>.value(
      value: _viewModel,
      child: Consumer<CustomerOrderViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.10),
                    colorScheme.surface,
                    colorScheme.secondary.withValues(alpha: 0.08),
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
                              color: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_ios_new),
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Menunggu Driver',
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
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
                                  Text(
                                    'Searching for nearby drivers...',
                                    textAlign: TextAlign.center,
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    viewModel.message ??
                                        'Tunggu sebentar, mencari driver terdekat.',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
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
                                              color: colorScheme.secondary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: colorScheme.secondary
                                                    .withValues(alpha: 0.18),
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Pembatalan otomatis tersedia',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurface,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${viewModel.buttonCountdown} detik',
                                                  style: textTheme.titleMedium
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurface,
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
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                                disabledBackgroundColor: colorScheme.error
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                              label: Text(
                                'Batalkan Pesanan',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onError,
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
    final colorScheme = Theme.of(context).colorScheme;

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
                      colorScheme.primary.withValues(alpha: 0.40),
                      colorScheme.primary.withValues(alpha: 0.0),
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
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.95),
                      colorScheme.secondary.withValues(alpha: 0.95),
                    ],
                  ),
                  border: Border.all(
                    color: colorScheme.onPrimary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.delivery_dining,
                  color: colorScheme.onPrimary,
                  size: 42,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final scale = 0.45 + (eased * 0.55);
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.5;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary.withValues(alpha: 0.05),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
