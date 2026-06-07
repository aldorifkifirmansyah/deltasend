import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/order_model.dart';
import '../services/routing_service.dart';

class MapViewModel extends ChangeNotifier {
  final RoutingService _routingService = RoutingService();
  final OrderService _orderService = OrderService();

  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  OrderModel? _currentOrder;
  StreamSubscription<Position>? _positionStream;
  LatLng? _lastRouteUpdatePos;
  bool _isAtLocation = false;
  bool _isAutoCenter = true;

  final MapController mapController = MapController();
  TickerProvider? _vsync;
  AnimationController? _cameraAnimController;

  LatLng? get currentLocation => _currentLocation;
  List<LatLng> get routePoints => _routePoints;
  OrderModel? get currentOrder => _currentOrder;
  bool get isAtLocation => _isAtLocation;
  bool get isAutoCenter => _isAutoCenter;

  void setTickerProvider(TickerProvider vsync) {
    _vsync = vsync;
  }

  @override
  void dispose() {
    _cameraAnimController?.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  void disableAutoCenter() {
    if (_isAutoCenter) {
      _isAutoCenter = false;
      notifyListeners();
    }
  }

  void enableAutoCenter() {
    if (!_isAutoCenter) {
      _isAutoCenter = true;
      _updateMapCamera();
      notifyListeners();
    }
  }

  void _updateMapCamera() {
    if (_currentLocation == null) return;

    if (_vsync == null) {
      // Fallback jika tidak ada vsync (tidak bisa animasi)
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [_currentLocation!],
          padding: const EdgeInsets.only(bottom: 250.0),
          maxZoom: 16.0,
        ),
      );
      return;
    }

    // Mendapatkan target parameter dari _currentLocation beserta padding
    final targetCamera = CameraFit.coordinates(
      coordinates: [_currentLocation!],
      padding: const EdgeInsets.only(bottom: 250.0),
      maxZoom: 16.0,
    ).fit(mapController.camera);

    final destLocation = targetCamera.center;
    final destZoom = targetCamera.zoom;

    final latTween = Tween<double>(
      begin: mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: mapController.camera.zoom,
      end: destZoom,
    );

    _cameraAnimController?.dispose();
    _cameraAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: _vsync!,
    ); // Animasi yang smooth (sliding)

    final Animation<double> animation = CurvedAnimation(
      parent: _cameraAnimController!,
      curve: Curves.fastOutSlowIn,
    );

    _cameraAnimController!.addListener(() {
      mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _cameraAnimController!.forward();
  }

  double get _distanceInMeters {
    if (_currentLocation == null || _currentOrder == null) return 0.0;
    LatLng targetPoint = _currentOrder!.status == OrderStatus.pickingUp
        ? _currentOrder!.pickupLocation
        : _currentOrder!.destinationLocation;

    return Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      targetPoint.latitude,
      targetPoint.longitude,
    );
  }

  String get distanceToTarget {
    if (_currentLocation == null || _currentOrder == null) return '-';
    double dist = _distanceInMeters;
    if (dist >= 1000) {
      return '${(dist / 1000).toStringAsFixed(1)} KM';
    }
    return '${dist.toStringAsFixed(0)} Meter';
  }

  String get estimatedTime {
    if (_currentLocation == null || _currentOrder == null) return '-';
    double distKm = _distanceInMeters / 1000;
    int mins = ((distKm / 15) * 60).ceil();
    if (mins < 1) return '< 1 menit';
    return '$mins menit';
  }

  String get activeTargetName {
    if (_currentOrder == null) return '-';
    return _currentOrder!.status == OrderStatus.pickingUp
        ? _currentOrder!.pickupAddress
        : _currentOrder!.destinationAddress;
  }

  void setOrder(OrderModel order) {
    _currentOrder = order;
    notifyListeners();
  }

  Future<void> fetchOrderData(String orderId) async {
    try {
      final order = await _orderService.fetchOrderById(orderId);

      if (order == null) {
        debugPrint('Order dengan ID $orderId tidak ditemukan');
        return;
      }
      // if (doc.exists) {
      //   _currentOrder = OrderModel.fromFirestore(doc);
      //   notifyListeners();

      //   if (_currentLocation != null) {
      //     loadRoute(_currentLocation!);
      //   }
      // }
      setOrder(order);
    } catch (e) {
      debugPrint("Gagal fetch order: $e");
    }
  }

  Future<void> initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    startTracking();
  }

  void updateCameraBounds() {
    if (_currentLocation == null || _currentOrder == null) return;

    LatLng targetPoint = _currentOrder!.status == OrderStatus.pickingUp
        ? _currentOrder!.pickupLocation
        : _currentOrder!.destinationLocation;

    final bounds = LatLngBounds.fromPoints([_currentLocation!, targetPoint]);

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 50.0,
          left: 50.0,
          right: 50.0,
          bottom: 250.0, // Extra padding bawah agar tidak tertutup Card UI
        ),
      ),
    );
  }

  void fitBounds() {
    if (_currentLocation == null || _currentOrder == null) return;

    LatLng targetPoint = _currentOrder!.status == OrderStatus.pickingUp
        ? _currentOrder!.pickupLocation
        : _currentOrder!.destinationLocation;

    final bounds = LatLngBounds.fromPoints([_currentLocation!, targetPoint]);
    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100.0)),
    );
  }

  void startTracking() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          LatLng newPos = LatLng(position.latitude, position.longitude);

          _currentLocation = newPos;
          notifyListeners();

          if (_currentOrder != null && _routePoints.isNotEmpty) {
            updateCameraBounds();
          }

          if (_lastRouteUpdatePos == null) {
            loadRoute(newPos);
            _lastRouteUpdatePos = newPos;
            updateCameraBounds();
          } else {
            double distance = Geolocator.distanceBetween(
              _lastRouteUpdatePos!.latitude,
              _lastRouteUpdatePos!.longitude,
              position.latitude,
              position.longitude,
            );

            if (distance > 50) {
              loadRoute(newPos);
              _lastRouteUpdatePos = newPos;
              updateCameraBounds();
            }
          }

          if (_currentOrder != null) {
            LatLng target = _currentOrder!.status == OrderStatus.pickingUp
                ? _currentOrder!.pickupLocation
                : _currentOrder!.destinationLocation;

            double distanceToTarget = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              target.latitude,
              target.longitude,
            );

            _isAtLocation = distanceToTarget < 50;
            notifyListeners();

            _orderService.updateDriverLocation(
              orderId: _currentOrder!.orderId,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          }
        });
  }

  Future<void> loadRoute(LatLng start) async {
    if (_currentOrder == null) return;

    LatLng? target;

    if (_currentOrder!.status == OrderStatus.pickingUp) {
      target = _currentOrder!.pickupLocation;
    } else if (_currentOrder!.status == OrderStatus.delivering) {
      target = _currentOrder!.destinationLocation;
    }

    if (target == null) {
      _routePoints.clear();
      notifyListeners();
      return;
    }

    try {
      _routePoints = await _routingService.getRoute(start, target);
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal load route: $e');
    }
  }

  Future<void> updateStatus() async {
    if (_currentOrder == null) return;

    OrderStatus? nextStatus;

    if (_currentOrder!.status == OrderStatus.pickingUp) {
      nextStatus = OrderStatus.delivering;
    } else if (_currentOrder!.status == OrderStatus.delivering) {
      nextStatus = OrderStatus.completed;
    }

    if (nextStatus == null) return;

    try {
      await _orderService.updateOrderStatus(
        orderId: _currentOrder!.orderId,
        status: nextStatus.name,
      );

      _currentOrder!.status = nextStatus;

      // Recalculate proximity based on new target
      if (_currentLocation != null && nextStatus != OrderStatus.completed) {
        LatLng newTarget = nextStatus == OrderStatus.pickingUp
            ? _currentOrder!.pickupLocation
            : _currentOrder!.destinationLocation;

        double distanceToNewTarget = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          newTarget.latitude,
          newTarget.longitude,
        );

        _isAtLocation = distanceToNewTarget < 50;
      } else if (nextStatus == OrderStatus.completed) {
        _isAtLocation = false;
        _routePoints.clear();
      }

      if (_currentLocation != null && nextStatus != OrderStatus.completed) {
        await loadRoute(_currentLocation!);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Gagal update status order: $e');
    }
  }
}
