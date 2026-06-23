import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // DASHBOARD - ONE TIME
  // =========================================================

  Future<int> getTotalOrders() async {
    final snapshot = await _firestore.collection('orders').get();

    return snapshot.docs.length;
  }

  Future<int> getActiveDrivers() async {
    final snapshot = await _firestore
        .collection('driver_locations')
        .where('is_online', isEqualTo: true)
        .get();

    return snapshot.docs.length;
  }

  Future<int> getOngoingOrders() async {
    final snapshot = await _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: ['accepted', 'pickingUp', 'delivering', 'onDelivery'],
        )
        .get();

    return snapshot.docs.length;
  }

  Future<int> getCompletedOrders() async {
    final snapshot = await _firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .get();

    return snapshot.docs.length;
  }

  // =========================================================
  // DASHBOARD - REAL TIME
  // =========================================================

  Stream<int> watchTotalOrdersCount() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchActiveDriversCount() {
    return _firestore
        .collection('driver_locations')
        .where('is_online', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchOngoingOrdersCount() {
    return _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: ['accepted', 'pickingUp', 'delivering', 'onDelivery'],
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchCompletedOrdersCount() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveDriverLocations() {
    return _firestore
        .collection('driver_locations')
        .where('is_online', isEqualTo: true)
        .snapshots();
  }

  // =========================================================
  // USERS
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllUsers() {
    return _firestore.collection('users').snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserById(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getUsersByRole(
    String role,
  ) async {
    return _firestore.collection('users').where('role', isEqualTo: role).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserById(String uid) async {
    return _firestore.collection('users').doc(uid).get();
  }

  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // =========================================================
  // ORDERS
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrderById(
    String orderId,
  ) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getAllOrders() async {
    return _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getOrdersByStatus(
    String status,
  ) async {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getOrderById(
    String orderId,
  ) async {
    return _firestore.collection('orders').doc(orderId).get();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // DRIVER LOCATION
  // =========================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriverLocation(
    String driverId,
  ) {
    return _firestore.collection('driver_locations').doc(driverId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getDriverLocationStream(
    String driverId,
  ) {
    return watchDriverLocation(driverId);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDriverLocation(
    String driverId,
  ) async {
    return _firestore.collection('driver_locations').doc(driverId).get();
  }

  // =========================================================
  // TRACKING
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveOrdersStream() {
    return _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: ['accepted', 'pickingUp', 'delivering', 'onDelivery'],
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTrackingOrders() {
    return _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: [
            'accepted',
            'pickingUp',
            'delivering',
            'onDelivery',
            'completed',
          ],
        )
        .snapshots();
  }

  // =========================================================
  // PRICING CONFIG
  // =========================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPricingConfig() {
    return _firestore.collection('pricing_config').doc('default').snapshots();
  }

  Future<void> updatePricingConfig({
    required int costPerKm,
    required String updatedBy,
  }) async {
    await _firestore.collection('pricing_config').doc('default').set({
      'cost_per_km': costPerKm,
      'updated_by': updatedBy,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================================================
  // WEIGHT CATEGORIES
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWeightCategories() {
    return _firestore.collection('weight_categories').snapshots();
  }

  Future<void> updateWeightCategory({
    required String categoryId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('weight_categories').doc(categoryId).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // RATINGS
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRatings() {
    return _firestore
        .collection('ratings')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getRatingsByDriver(
    String driverId,
  ) async {
    return _firestore
        .collection('ratings')
        .where('driver_id', isEqualTo: driverId)
        .get();
  }
}
