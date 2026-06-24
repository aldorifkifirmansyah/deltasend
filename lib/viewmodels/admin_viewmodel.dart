import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class AdminViewModel extends ChangeNotifier {
  final AdminService _adminService;

  AdminViewModel({AdminService? adminService})
    : _adminService = adminService ?? AdminService();

  bool isLoading = false;
  String? dashboardError;

  int totalOrders = 0;
  int activeDrivers = 0;
  int ongoingOrders = 0;
  int completedOrders = 0;

  String selectedUserRole = 'driver';
  String userSearchQuery = '';

  String selectedOrderStatus = 'all';
  String orderSearchQuery = '';

  bool _dashboardInitialized = false;

  StreamSubscription<int>? _totalOrdersSubscription;
  StreamSubscription<int>? _activeDriversSubscription;
  StreamSubscription<int>? _ongoingOrdersSubscription;
  StreamSubscription<int>? _completedOrdersSubscription;

  // ============================================================
  // DASHBOARD
  // ============================================================

  void initAdminDashboard() {
    if (_dashboardInitialized) return;

    _dashboardInitialized = true;
    isLoading = true;
    dashboardError = null;
    notifyListeners();

    int loadedStreams = 0;

    void markStreamLoaded() {
      loadedStreams++;

      if (loadedStreams >= 4 && isLoading) {
        isLoading = false;
        notifyListeners();
      }
    }

    void handleError(Object error) {
      dashboardError = 'Gagal memuat dashboard.';
      isLoading = false;
      debugPrint('Admin dashboard error: $error');
      notifyListeners();
    }

    _totalOrdersSubscription = _adminService.watchTotalOrders().listen((value) {
      totalOrders = value;
      markStreamLoaded();
      notifyListeners();
    }, onError: handleError);

    _activeDriversSubscription = _adminService.watchActiveDrivers().listen((
      value,
    ) {
      activeDrivers = value;
      markStreamLoaded();
      notifyListeners();
    }, onError: handleError);

    _ongoingOrdersSubscription = _adminService.watchOngoingOrders().listen((
      value,
    ) {
      ongoingOrders = value;
      markStreamLoaded();
      notifyListeners();
    }, onError: handleError);

    _completedOrdersSubscription = _adminService.watchCompletedOrders().listen((
      value,
    ) {
      completedOrders = value;
      markStreamLoaded();
      notifyListeners();
    }, onError: handleError);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentOrders({
    int limit = 4,
  }) {
    return _adminService.watchRecentOrders(limit: limit);
  }

  // ============================================================
  // USERS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSelectedUsers() {
    return _adminService.watchUsersByRole(selectedUserRole);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDetail(String uid) {
    return _adminService.watchUserById(uid);
  }

  void changeUserRole(String role) {
    if (selectedUserRole == role) return;

    selectedUserRole = role;
    notifyListeners();
  }

  void changeUserSearchQuery(String query) {
    userSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  bool isUserMatchSearch(Map<String, dynamic> data) {
    if (userSearchQuery.isEmpty) return true;

    final String email = data['email']?.toString().toLowerCase() ?? '';

    final String name = data['name']?.toString().toLowerCase() ?? '';

    final String phone = data['phone']?.toString().toLowerCase() ?? '';

    return email.contains(userSearchQuery) ||
        name.contains(userSearchQuery) ||
        phone.contains(userSearchQuery);
  }

  // ============================================================
  // ORDERS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOrders() {
    return _adminService.watchAllOrders();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrderDetail(
    String orderId,
  ) {
    return _adminService.watchOrderById(orderId);
  }

  void changeOrderStatus(String status) {
    if (selectedOrderStatus == status) return;

    selectedOrderStatus = status;
    notifyListeners();
  }

  void changeOrderSearchQuery(String query) {
    orderSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  bool isOrderMatchStatus(String status) {
    final String normalized = status.trim();

    if (selectedOrderStatus == 'all') {
      return true;
    }

    if (selectedOrderStatus == 'onDelivery') {
      return normalized == 'pickingUp' ||
          normalized == 'delivering' ||
          normalized == 'onDelivery';
    }

    if (selectedOrderStatus == 'cancelled') {
      return normalized == 'cancelled' || normalized == 'cancel';
    }

    return normalized == selectedOrderStatus;
  }

  bool isOrderMatchSearch(String documentId, Map<String, dynamic> data) {
    if (orderSearchQuery.isEmpty) return true;

    final String orderId = documentId.toLowerCase();

    final String pickup =
        data['pickup_address']?.toString().toLowerCase() ?? '';

    final String destination =
        (data['dest_address'] ?? data['destination_address'])
            ?.toString()
            .toLowerCase() ??
        '';

    final String item =
        data['item_description']?.toString().toLowerCase() ?? '';

    return orderId.contains(orderSearchQuery) ||
        pickup.contains(orderSearchQuery) ||
        destination.contains(orderSearchQuery) ||
        item.contains(orderSearchQuery);
  }

  // ============================================================
  // FORMATTER
  // ============================================================

  String statusLabel(String status) {
    switch (status) {
      case 'delivering':
      case 'onDelivery':
        return 'On Delivery';

      case 'completed':
        return 'Completed';

      case 'cancelled':
      case 'cancel':
        return 'Cancelled';

      case 'pickingUp':
        return 'Picking Up';

      case 'pending':
        return 'Pending';

      case 'accepted':
        return 'Accepted';

      default:
        return status.isEmpty ? '-' : status;
    }
  }

  String formatTime(dynamic value) {
    final DateTime? date = _toDateTime(value);

    if (date == null) return '-';

    final String hour = date.hour.toString().padLeft(2, '0');

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String formatDate(dynamic value) {
    final DateTime? date = _toDateTime(value);

    if (date == null) return '-';

    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day-$month-${date.year}';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String formatCurrency(dynamic value) {
    final double number = double.tryParse(value?.toString() ?? '') ?? 0;

    final String raw = number.round().toString();
    final StringBuffer result = StringBuffer();

    for (int index = 0; index < raw.length; index++) {
      final int remaining = raw.length - index;

      result.write(raw[index]);

      if (remaining > 1 && remaining % 3 == 1) {
        result.write('.');
      }
    }

    return 'Rp $result';
  }

  String formatDistanceText(dynamic value) {
    final double distance = double.tryParse(value?.toString() ?? '') ?? 0;

    return '${distance.toStringAsFixed(2)} km';
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double calculateDistanceKm({
    required double driverLat,
    required double driverLng,
    required double destinationLat,
    required double destinationLng,
  }) {
    const double earthRadiusKm = 6371;

    final double latitudeDifference = _degreeToRadian(
      destinationLat - driverLat,
    );

    final double longitudeDifference = _degreeToRadian(
      destinationLng - driverLng,
    );

    final double calculation =
        sin(latitudeDifference / 2) * sin(latitudeDifference / 2) +
        cos(_degreeToRadian(driverLat)) *
            cos(_degreeToRadian(destinationLat)) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2);

    final double centralAngle =
        2 * atan2(sqrt(calculation), sqrt(1 - calculation));

    return earthRadiusKm * centralAngle;
  }

  double _degreeToRadian(double degree) {
    return degree * pi / 180;
  }

  String formatRemainingDistance({
    required dynamic driverLat,
    required dynamic driverLng,
    required dynamic destinationLat,
    required dynamic destinationLng,
  }) {
    final double latitude = double.tryParse(driverLat?.toString() ?? '') ?? 0;

    final double longitude = double.tryParse(driverLng?.toString() ?? '') ?? 0;

    final double targetLatitude =
        double.tryParse(destinationLat?.toString() ?? '') ?? 0;

    final double targetLongitude =
        double.tryParse(destinationLng?.toString() ?? '') ?? 0;

    if (latitude == 0 ||
        longitude == 0 ||
        targetLatitude == 0 ||
        targetLongitude == 0) {
      return '-';
    }

    final double distance = calculateDistanceKm(
      driverLat: latitude,
      driverLng: longitude,
      destinationLat: targetLatitude,
      destinationLng: targetLongitude,
    );

    return '${distance.toStringAsFixed(2)} km';
  }

  @override
  void dispose() {
    _totalOrdersSubscription?.cancel();
    _activeDriversSubscription?.cancel();
    _ongoingOrdersSubscription?.cancel();
    _completedOrdersSubscription?.cancel();

    super.dispose();
  }
}
