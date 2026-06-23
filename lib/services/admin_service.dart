import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= DASHBOARD =================

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
          whereIn: [
            'pending',
            'accepted',
            'pickingUp',
            'delivering',
            'onDelivery',
          ],
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

  // ================= USERS =================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserById(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getUsersByRole(String role) async {
    return _firestore.collection('users').where('role', isEqualTo: role).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserById(String uid) async {
    return _firestore.collection('users').doc(uid).get();
  }

  // ================= ORDERS =================

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOrderById(String orderId) {
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

  // ================= TRACKING =================

  Stream<DocumentSnapshot<Map<String, dynamic>>> getDriverLocationStream(
    String driverId,
  ) {
    return _firestore.collection('driver_locations').doc(driverId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveOrdersStream() {
    return _firestore
        .collection('orders')
        .where(
          'status',
          whereIn: [
            'pickingUp',
            'delivering',
            'onDelivery',
          ],
        )
        .snapshots();
  }
}