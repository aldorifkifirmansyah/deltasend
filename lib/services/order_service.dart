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

  // 5. method buat listen perubahan order dengan status 'pending'
  Stream<List<OrderModel>> watchPendingOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        return OrderModel.fromFirestore(doc);
      }).toList();

      orders.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(0);
        final bDate = b.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      return orders;
    });
  }

  // 6. method buat driver terima order (update driver_id dan status)
  Future<void> acceptOrder({
    required String orderId,
    required String driverId,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'driver_id': driverId,
      'status': OrderStatus.pickingUp.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // 7. method buat customer bikin order baru (status awal: pending)
  Future<String> createOrder({
    required String customerId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String destAddress,
    required double destLat,
    required double destLng,
    required String itemDescription,
    String? weightCategoryId,
    double distanceKm = 0.0,
    double totalCost = 0.0,
  }) async {
    final docRef = await _db.collection('orders').add({
      'customer_id': customerId,
      // driver_id null = belum ada driver yang ambil (aman dgn OrderModel)
      'driver_id': null,
      'weight_category_id': weightCategoryId,
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dest_address': destAddress,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'item_description': itemDescription,
      'distance_km': distanceKm,
      'total_cost': totalCost,
      'status': OrderStatus.pending.name,
      'proof_photo_url': '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }
}