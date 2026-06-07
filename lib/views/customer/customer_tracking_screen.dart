import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/routing_service.dart';
import 'package:flutter/cupertino.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String orderId;

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final OrderService _orderService = OrderService();
  final RoutingService _routingService = RoutingService();
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  List<LatLng> _routePoints = [];
  LatLng? _lastRouteCalcPos;
  bool _isCalculatingRoute = false;

  void _maybeUpdateRoute(LatLng driverPos, LatLng destPos) {
    if (_isCalculatingRoute) return;

    if (_lastRouteCalcPos != null && _routePoints.isNotEmpty) {
      final moved = _distance.as(
        LengthUnit.Meter,
        _lastRouteCalcPos!,
        driverPos,
      );
      if (moved <= 50) return;
    }

    _lastRouteCalcPos = driverPos;
    _calculateRoute(driverPos, destPos);
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    _isCalculatingRoute = true;
    try {
      final points = await _routingService.getRoute(start, end);
      if (!mounted) return;
      setState(() => _routePoints = points);
    } catch (_) {
      // biarkan rute lama jika gagal
    } finally {
      _isCalculatingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak Driver'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<OrderModel?>(
        stream: _orderService.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Terjadi kesalahan: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Order tidak ditemukan'));
          }

          final destPos = order.destinationLocation;
          final pickupPos = order.pickupLocation;
          final driverPos = order.driverLocation;

          // Determine target position based on order status
          LatLng? targetPos;
          if (order.status == OrderStatus.accepted ||
              order.status == OrderStatus.pickingUp) {
            // Driver is heading to pickup location
            targetPos = pickupPos;
          } else if (order.status == OrderStatus.delivering) {
            // Driver is heading to destination location
            targetPos = destPos;
          }

          if (driverPos != null &&
              targetPos != null &&
              order.status != OrderStatus.completed) {
            _maybeUpdateRoute(driverPos, targetPos);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: driverPos ?? destPos,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.deltasend.app',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blue,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Pickup marker - show during accepted/pickingUp phases
                      if (order.status == OrderStatus.accepted ||
                          order.status == OrderStatus.pickingUp)
                        Marker(
                          point: order.pickupLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            CupertinoIcons.location_north_fill,
                            color: Colors.orange,
                            size: 35,
                          ),
                        )
                      // Destination marker - show during delivering/completed phases
                      else if (order.status == OrderStatus.delivering ||
                          order.status == OrderStatus.completed)
                        Marker(
                          point: order.destinationLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            CupertinoIcons.location_solid,
                            color: Colors.red,
                            size: 35,
                          ),
                        ),
                      // Pickup reference marker - show during delivering phase for context
                      if (order.status == OrderStatus.delivering)
                        Marker(
                          point: order.pickupLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            CupertinoIcons.location_north_fill,
                            color: Colors.orange,
                            size: 30,
                          ),
                        ),
                      // Driver marker
                      if (driverPos != null)
                        Marker(
                          point: driverPos,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.green,
                            size: 35,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: _buildPanel(order),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(OrderModel order) {
    if (order.status == OrderStatus.completed) {
      return Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Pesanan telah tiba!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Kembali ke Home'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine current target and description based on status
    final isHeadingToPickup =
        order.status == OrderStatus.accepted ||
        order.status == OrderStatus.pickingUp;
    final locationLabel = isHeadingToPickup
        ? 'Lokasi Penjemputan'
        : 'Lokasi Tujuan';
    final locationAddress = isHeadingToPickup
        ? order.pickupAddress
        : order.destinationAddress;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusChip(order.status),
            const SizedBox(height: 12),
            Text(
              locationLabel,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              locationAddress,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (order.driverLocation == null) ...[
              const SizedBox(height: 12),
              const Text(
                'Menunggu driver bergerak...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    final label = status == OrderStatus.accepted
        ? 'Menuju Lokasi Penjemputan'
        : status == OrderStatus.pickingUp
        ? 'Menjemput'
        : status == OrderStatus.delivering
        ? 'Mengantar'
        : status.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
