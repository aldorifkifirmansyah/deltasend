import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../viewmodels/map_viewmodel.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class MapDriverScreen extends StatefulWidget {
  final String orderId;

  const MapDriverScreen({super.key, required this.orderId});

  @override
  State<MapDriverScreen> createState() => _MapDriverScreenState();
}

class _MapDriverScreenState extends State<MapDriverScreen>
    with TickerProviderStateMixin {
  String _base64Photo = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<MapViewModel>();
      viewModel.setTickerProvider(this);
      viewModel.fetchOrderData(widget.orderId);
      viewModel.initLocation();
    });
  }

  Future<void> _captureProofPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 20,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _base64Photo = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint('Gagal capture photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    }
  }

  Future<void> _completeOrderWithPhoto() async {
    if (_base64Photo.isEmpty || widget.orderId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final viewModel = context.read<MapViewModel>();
      await viewModel.completeOrderWithPhoto(
        orderId: widget.orderId,
        base64Photo: _base64Photo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan berhasil diselesaikan')),
        );
      }
    } catch (e) {
      debugPrint('Gagal complete order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan pesanan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MapViewModel>();
    final currentLocation = viewModel.currentLocation;
    final routePoints = viewModel.routePoints;
    final currentOrder = viewModel.currentOrder;

    LatLng? targetPoint;
    String statusText = 'Memuat Pesanan...';
    String buttonText = 'Selesai';
    VoidCallback? buttonOnPressed;
    bool isButtonEnabled = false;

    if (currentOrder != null) {
      if (currentOrder.status == OrderStatus.pickingUp) {
        targetPoint = currentOrder.pickupLocation;
        statusText = 'Menuju Lokasi Penjemputan';
        buttonText = 'Pick Up Pesanan';
        buttonOnPressed = viewModel.isAtLocation
            ? () => viewModel.updateStatus()
            : null;
        isButtonEnabled = viewModel.isAtLocation;
      } else if (currentOrder.status == OrderStatus.delivering) {
        targetPoint = currentOrder.destinationLocation;
        statusText = 'Menuju Lokasi Pengiriman';

        if (viewModel.distanceToTarget
                    .replaceAll(' Meter', '')
                    .replaceAll(' KM', '') !=
                '-' &&
            viewModel.distanceInMeters > 50) {
          buttonText = 'Menuju Lokasi Tujuan';
          buttonOnPressed = null;
          isButtonEnabled = false;
        } else if (_base64Photo.isEmpty && viewModel.distanceInMeters <= 50) {
          buttonText = 'Ambil Foto Bukti Pengantaran';
          buttonOnPressed = _captureProofPhoto;
          isButtonEnabled = true;
        } else if (_base64Photo.isNotEmpty) {
          buttonText = 'Selesaikan Pesanan';
          buttonOnPressed = _isLoading ? null : _completeOrderWithPhoto;
          isButtonEnabled = !_isLoading;
        } else {
          buttonText = 'Menuju Lokasi Tujuan';
          buttonOnPressed = null;
          isButtonEnabled = false;
        }
      } else {
        statusText = 'Pesanan Selesai';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Driver'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: viewModel.mapController,
            options: MapOptions(
              initialCenter: currentLocation ?? const LatLng(-8.1689, 113.7022),
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && viewModel.isAutoCenter) {
                  viewModel.disableAutoCenter();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.deltasend.app',
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.delivery_dining,
                        color: Colors.green,
                        size: 35,
                      ),
                    ),
                  if (targetPoint != null)
                    Marker(
                      point: targetPoint,
                      width: 40,
                      height: 40,
                      child: Icon(
                        CupertinoIcons.location_solid,
                        color: Colors.red,
                        size: 35,
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (!viewModel.isAutoCenter)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                mini: true,
                onPressed: () => viewModel.enableAutoCenter(),
                child: const Icon(CupertinoIcons.location_north_fill),
              ),
            ),

          if (currentOrder != null &&
              currentOrder.status != OrderStatus.completed)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viewModel.activeTargetName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            Icons.route,
                            'Jarak',
                            viewModel.distanceToTarget,
                            Theme.of(context).colorScheme.primary,
                          ),
                          _buildStatItem(
                            Icons.access_time,
                            'Estimasi',
                            viewModel.estimatedTime,
                            Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isButtonEnabled
                                      ? Theme.of(context).colorScheme.secondary
                                      : Colors.grey[400],
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: buttonOnPressed,
                                child: Text(
                                  buttonText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
