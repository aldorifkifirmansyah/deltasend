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

  Future<void> initAdminDashboard() async {
    isLoading = true;
    notifyListeners();

    try {
      totalOrders = await _adminService.getTotalOrders();
      activeDrivers = await _adminService.getActiveDrivers();
      ongoingOrders = await _adminService.getOngoingOrders();
      completedOrders = await _adminService.getCompletedOrders();
    } catch (e) {
      debugPrint('Error initAdminDashboard: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // ================= USERS =================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSelectedUsers() {
    return _adminService.watchUsersByRole(selectedUserRole);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDetail(String uid) {
    return _adminService.watchUserById(uid);
  }

  void changeUserRole(String role) {
    selectedUserRole = role;
    notifyListeners();
  }

  void changeUserSearchQuery(String query) {
    userSearchQuery = query.toLowerCase();
    notifyListeners();
  }

  bool isUserMatchSearch(Map<String, dynamic> data) {
    final email = data['email']?.toString().toLowerCase() ?? '';
    final name = data['name']?.toString().toLowerCase() ?? '';
    final phone = data['phone']?.toString().toLowerCase() ?? '';

    return email.contains(userSearchQuery) ||
        name.contains(userSearchQuery) ||
        phone.contains(userSearchQuery);
  }

  // ================= ORDERS =================

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
    orderSearchQuery = query.toLowerCase();
    notifyListeners();
  }

  bool isOrderMatchStatus(String status) {
    if (selectedOrderStatus == 'all') return true;

    if (selectedOrderStatus == 'onDelivery') {
      return status == 'delivering' ||
          status == 'onDelivery' ||
          status == 'pickingUp';
    }

    if (selectedOrderStatus == 'cancelled') {
      return status == 'cancelled' || status == 'cancel';
    }

    return status == selectedOrderStatus;
  }

  bool isOrderMatchSearch(String docId, Map<String, dynamic> data) {
    final orderId = docId.toLowerCase();
    final pickup = data['pickup_address']?.toString().toLowerCase() ?? '';
    final dest = (data['dest_address'] ?? data['destination_address'])
            ?.toString()
            .toLowerCase() ??
        '';
    final item = data['item_description']?.toString().toLowerCase() ?? '';

    return orderId.contains(orderSearchQuery) ||
        pickup.contains(orderSearchQuery) ||
        dest.contains(orderSearchQuery) ||
        item.contains(orderSearchQuery);
  }

  // ================= FORMATTER =================

  String statusLabel(String status) {
    switch (status) {
      case 'delivering':
      case 'onDelivery':
        return 'On Delivery';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'cancel':
        return 'Cancel';
      case 'pickingUp':
        return 'Picking Up';
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      default:
        return status;
    }
  }

  String formatTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '-';
  }

  String formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      return '${date.day}-${date.month}-${date.year}';
    }
    return '-';
  }

  String formatCurrency(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    final raw = number.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'Rp. $buffer';
  }

  String formatDistanceText(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return '${number.toStringAsFixed(2)} km';
  }

  // ================= LIVE TRACKING GPS DISTANCE =================

  double calculateDistanceKm({
    required double driverLat,
    required double driverLng,
    required double destLat,
    required double destLng,
  }) {
    const double earthRadiusKm = 6371;

    final double dLat = _degToRad(destLat - driverLat);
    final double dLng = _degToRad(destLng - driverLng);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
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
    final double dLat = double.tryParse(driverLat.toString()) ?? 0;
    final double dLng = double.tryParse(driverLng.toString()) ?? 0;
    final double targetLat = double.tryParse(destLat.toString()) ?? 0;
    final double targetLng = double.tryParse(destLng.toString()) ?? 0;

    if (dLat == 0 || dLng == 0 || targetLat == 0 || targetLng == 0) {
      return '-';
    }

    final distance = calculateDistanceKm(
      driverLat: dLat,
      driverLng: dLng,
      destLat: targetLat,
      destLng: targetLng,
    );

    return '${distance.toStringAsFixed(2)} KM';
  }
}