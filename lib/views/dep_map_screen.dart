import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import '../viewmodels/map_viewmodel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final MapViewModel _viewModel;
  LatLng? _lastMapCenter;

  @override
  void initState() {
    super.initState();
    _viewModel = MapViewModel();
    _viewModel.fetchOrderData('order_test_123');
    _viewModel.initLocation();
    _viewModel.addListener(_onViewModelChange);
  }

  void _onViewModelChange() {
    final loc = _viewModel.currentLocation;
    if (loc != null && loc != _lastMapCenter) {
      _lastMapCenter = loc;
      _mapController.move(loc, 15.0);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          final currentLocation = _viewModel.currentLocation;
          final routePoints = _viewModel.routePoints;
          final currentOrder = _viewModel.currentOrder;

          LatLng? targetPoint;
          String statusText = 'Memuat Pesanan...';
          String buttonText = 'Selesai';

          if (currentOrder != null) {
            if (currentOrder.status == OrderStatus.pickingUp) {
              targetPoint = currentOrder.pickupLocation;
              statusText = 'Menuju Lokasi Jemput';
              buttonText = 'Tiba di Penjemputan';
            } else if (currentOrder.status == OrderStatus.delivering) {
              targetPoint = currentOrder.destinationLocation;
              statusText = 'Menuju Lokasi Pengiriman';
              buttonText = 'Selesaikan Pesanan';
            } else {
              statusText = 'Pesanan Selesai';
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      currentLocation ?? const LatLng(-8.1689, 113.7022),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.blue,
                            size: 35,
                          ),
                        ),
                      if (targetPoint != null)
                        Marker(
                          point: targetPoint,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.flag,
                            color: Colors.red,
                            size: 35,
                          ),
                        ),
                    ],
                  ),
                ],
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _viewModel.isAtLocation
                                  ? () => _viewModel.updateStatus()
                                  : null,
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
          );
        },
      ),
    );
  }
}
