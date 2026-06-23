import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class AdminViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool isLoading = false;

  int totalOrders = 0;
  int activeDrivers = 0;
  int ongoingOrders = 0;
  int completedOrders = 0;

  String selectedUserRole = 'driver';
  String userSearchQuery = '';

  String selectedOrderStatus = 'all';
  String orderSearchQuery = '';

  StreamSubscription<int>? _totalOrdersSubscription;

  StreamSubscription<int>? _activeDriversSubscription;

  StreamSubscription<int>? _ongoingOrdersSubscription;

  StreamSubscription<int>? _completedOrdersSubscription;

  bool _dashboardListenerStarted = false;

  final Set<String> _loadedDashboardMetrics = <String>{};

  // =========================================================
  // DASHBOARD
  // =========================================================

  void startDashboardListener() {
    if (_dashboardListenerStarted) {
      return;
    }

    _dashboardListenerStarted = true;
    isLoading = true;
    _loadedDashboardMetrics.clear();
    notifyListeners();

    _totalOrdersSubscription = _adminService.watchTotalOrdersCount().listen(
      (value) {
        totalOrders = value;
        _markMetricLoaded('total');
      },
      onError: (error) {
        debugPrint('watchTotalOrdersCount error: $error');

        _markMetricLoaded('total');
      },
    );

    _activeDriversSubscription = _adminService.watchActiveDriversCount().listen(
      (value) {
        activeDrivers = value;
        _markMetricLoaded('drivers');
      },
      onError: (error) {
        debugPrint('watchActiveDriversCount error: $error');

        _markMetricLoaded('drivers');
      },
    );

    _ongoingOrdersSubscription = _adminService.watchOngoingOrdersCount().listen(
      (value) {
        ongoingOrders = value;
        _markMetricLoaded('ongoing');
      },
      onError: (error) {
        debugPrint('watchOngoingOrdersCount error: $error');

        _markMetricLoaded('ongoing');
      },
    );

    _completedOrdersSubscription = _adminService
        .watchCompletedOrdersCount()
        .listen(
          (value) {
            completedOrders = value;
            _markMetricLoaded('completed');
          },
          onError: (error) {
            debugPrint('watchCompletedOrdersCount error: $error');

            _markMetricLoaded('completed');
          },
        );
  }

  void _markMetricLoaded(String metric) {
    _loadedDashboardMetrics.add(metric);

    if (_loadedDashboardMetrics.length >= 4) {
      isLoading = false;
    }

    notifyListeners();
  }

  Future<void> refreshDashboard() async {
    try {
      final List<int> results = await Future.wait<int>([
        _adminService.getTotalOrders(),
        _adminService.getActiveDrivers(),
        _adminService.getOngoingOrders(),
        _adminService.getCompletedOrders(),
      ]);

      totalOrders = results[0];
      activeDrivers = results[1];
      ongoingOrders = results[2];
      completedOrders = results[3];

      notifyListeners();
    } catch (error) {
      debugPrint('refreshDashboard error: $error');

      rethrow;
    }
  }

  Future<void> initAdminDashboard() async {
    startDashboardListener();

    if (!_dashboardListenerStarted) {
      await refreshDashboard();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveDriverLocations() {
    return _adminService.watchActiveDriverLocations();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserById(String uid) {
    return _adminService.getUserById(uid);
  }

  // =========================================================
  // USERS
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSelectedUsers() {
    return _adminService.watchUsersByRole(selectedUserRole);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllUsers() {
    return _adminService.watchAllUsers();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDetail(String uid) {
    return _adminService.watchUserById(uid);
  }

  void changeUserRole(String role) {
    selectedUserRole = role;
    notifyListeners();
  }

  void changeUserSearchQuery(String query) {
    userSearchQuery = query.trim().toLowerCase();

    notifyListeners();
  }

  bool isUserMatchSearch(Map<String, dynamic> data) {
    if (userSearchQuery.isEmpty) {
      return true;
    }

    final String email = data['email']?.toString().toLowerCase() ?? '';

    final String name = data['name']?.toString().toLowerCase() ?? '';

    final String phone = data['phone']?.toString().toLowerCase() ?? '';

    return email.contains(userSearchQuery) ||
        name.contains(userSearchQuery) ||
        phone.contains(userSearchQuery);
  }

  Future<void> updateAdminProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    await _adminService.updateUserProfile(
      uid: uid,
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      },
    );

    notifyListeners();
  }

  // =========================================================
  // ORDERS
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOrders() {
    return _adminService.watchAllOrders();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrderDetail(
    String orderId,
  ) {
    return _adminService.watchOrderById(orderId);
  }

  void changeOrderStatus(String status) {
    selectedOrderStatus = status;
    notifyListeners();
  }

  void changeOrderSearchQuery(String query) {
    orderSearchQuery = query.trim().toLowerCase();

    notifyListeners();
  }

  bool isOrderMatchStatus(String status) {
    final String normalizedStatus = status.trim();

    if (selectedOrderStatus == 'all') {
      return true;
    }

    if (selectedOrderStatus == 'onDelivery') {
      return normalizedStatus == 'accepted' ||
          normalizedStatus == 'pickingUp' ||
          normalizedStatus == 'delivering' ||
          normalizedStatus == 'onDelivery';
    }

    if (selectedOrderStatus == 'cancelled') {
      return normalizedStatus == 'cancelled' || normalizedStatus == 'cancel';
    }

    return normalizedStatus == selectedOrderStatus;
  }

  bool isOrderMatchSearch(String documentId, Map<String, dynamic> data) {
    if (orderSearchQuery.isEmpty) {
      return true;
    }

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

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _adminService.updateOrderStatus(orderId: orderId, status: status);
  }

  // =========================================================
  // TRACKING
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTrackingOrders() {
    return _adminService.watchTrackingOrders();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriverLocation(
    String driverId,
  ) {
    return _adminService.watchDriverLocation(driverId);
  }

  // =========================================================
  // FORMATTER
  // =========================================================

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

      case 'delayed':
        return 'Delayed';

      default:
        return status;
    }
  }

  String formatTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final DateTime date = createdAt.toDate();

      final String hour = date.hour.toString().padLeft(2, '0');

      final String minute = date.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    return '-';
  }

  String formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final DateTime date = createdAt.toDate();

      const List<String> months = [
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

      return '$day '
          '${months[date.month - 1]} '
          '${date.year}';
    }

    return '-';
  }

  String formatCurrency(dynamic value) {
    final double number = double.tryParse(value.toString()) ?? 0;

    final String raw = number.round().toString();

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

  String formatDistanceText(dynamic value) {
    final double number = double.tryParse(value.toString()) ?? 0;

    return '${number.toStringAsFixed(2)} km';
  }

  String formatRating(dynamic value) {
    final double? number = double.tryParse(value.toString());

    if (number == null || number == 0) {
      return '-';
    }

    return number.toStringAsFixed(1);
  }

  // =========================================================
  // GPS DISTANCE
  // =========================================================

  double calculateDistanceKm({
    required double driverLat,
    required double driverLng,
    required double destLat,
    required double destLng,
  }) {
    const double earthRadiusKm = 6371;

    final double dLat = _degToRad(destLat - driverLat);

    final double dLng = _degToRad(destLng - driverLng);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(driverLat)) *
            cos(_degToRad(destLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double degree) {
    return degree * pi / 180;
  }

  String formatRemainingDistance({
    required dynamic driverLat,
    required dynamic driverLng,
    required dynamic destLat,
    required dynamic destLng,
  }) {
    final double currentLat = double.tryParse(driverLat.toString()) ?? 0;

    final double currentLng = double.tryParse(driverLng.toString()) ?? 0;

    final double targetLat = double.tryParse(destLat.toString()) ?? 0;

    final double targetLng = double.tryParse(destLng.toString()) ?? 0;

    if (currentLat == 0 ||
        currentLng == 0 ||
        targetLat == 0 ||
        targetLng == 0) {
      return '-';
    }

    final double distance = calculateDistanceKm(
      driverLat: currentLat,
      driverLng: currentLng,
      destLat: targetLat,
      destLng: targetLng,
    );

    return '${distance.toStringAsFixed(2)} KM';
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
