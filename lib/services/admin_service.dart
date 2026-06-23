import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore;

  AdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // DASHBOARD
  // ============================================================

  Stream<int> watchTotalOrders() {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchActiveDrivers() {
    return _firestore
        .collection('driver_locations')
        .where('is_online', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchOngoingOrders() {
    return _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: const [
            'pending',
            'accepted',
            'pickingUp',
            'delivering',
            'onDelivery',
          ],
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchCompletedOrders() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentOrders({
    int limit = 4,
  }) {
    return _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ============================================================
  // USERS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserById(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getUsersByRole(String role) {
    return _firestore.collection('users').where('role', isEqualTo: role).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserById(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  // ============================================================
  // ORDERS
  // ============================================================

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

  Future<QuerySnapshot<Map<String, dynamic>>> getAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getOrdersByStatus(String status) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getOrderById(String orderId) {
    return _firestore.collection('orders').doc(orderId).get();
  }

  // ============================================================
  // TRACKING
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriverLocation(
    String driverId,
  ) {
    return _firestore.collection('driver_locations').doc(driverId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveOrders() {
    return _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: const ['pickingUp', 'delivering', 'onDelivery'],
        )
        .snapshots();
  }
}
