import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  // 1. buat instance Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 2. method buat fetch order berdasarkan ID
  Future<OrderModel?> fetchOrderById(String orderId) async {
    final doc = await _db.collection('orders').doc(orderId).get();

    if (!doc.exists) {
      return null;
    }

    return OrderModel.fromFirestore(doc);
  }

  // 3. method buat update lokasi driver dan status order
  Future<void> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    await _db.collection('orders').doc(orderId).set({
      'driver_lat': latitude,
      'driver_lng': longitude,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 4. method buat update status order (misal: 'pickingUp')
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}