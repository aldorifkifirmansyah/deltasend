import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  // 1. buat instance Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1b. listen satu dokumen order secara real-time
  Stream<OrderModel?> watchOrder(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

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

  // 5b. method buat listen order aktif milik driver (pickingUp / delivering)
  Stream<List<OrderModel>> watchActiveOrdersForDriver(String driverId) {
    // Query cukup filter driver_id (single field, gak butuh composite index).
    // Filter status & sort dilakukan di memory biar aman dari index Firestore.
    return _db
        .collection('orders')
        .where('driver_id', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      const activeStatuses = {OrderStatus.pickingUp, OrderStatus.delivering};

      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) => activeStatuses.contains(order.status))
          .toList();

      orders.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      return orders;
    });
  }

  // 5c. cek apakah driver masih punya order aktif (pickingUp / delivering)
  Future<bool> hasActiveOrderForDriver(String driverId) async {
    final snapshot = await _db
        .collection('orders')
        .where('driver_id', isEqualTo: driverId)
        .get();

    const activeStatuses = {OrderStatus.pickingUp, OrderStatus.delivering};

    return snapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .any((order) => activeStatuses.contains(order.status));
  }

  // 6. method buat driver terima order (update driver_id dan status)
  Future<void> acceptOrder({
    required String orderId,
    required String driverId,
  }) async {
    // 1. driver gak boleh punya lebih dari 1 order aktif
    final hasActive = await hasActiveOrderForDriver(driverId);
    if (hasActive) {
      throw Exception(
        'Driver masih memiliki order aktif. Selesaikan order tersebut terlebih dahulu.',
      );
    }

    final docRef = _db.collection('orders').doc(orderId);
    final doc = await docRef.get();

    // 2. order yang mau diambil harus masih ada & masih pending
    if (!doc.exists) {
      throw Exception('Order sudah tidak tersedia.');
    }

    final order = OrderModel.fromFirestore(doc);
    if (order.status != OrderStatus.pending) {
      throw Exception('Order sudah tidak tersedia.');
    }

    // 3. aman → ambil order
    await docRef.update({
      'driver_id': driverId,
      'status': OrderStatus.pickingUp.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // 6b. stream completed order milik customer yang belum dirating
  Stream<List<OrderModel>> watchCompletedUnratedOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customer_id', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) =>
              order.status == OrderStatus.completed && order.rating == null)
          .toList();

      orders.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      return orders;
    });
  }

  // 6c. submit rating: simpan ke order + hitung ulang rata-rata rating driver
  Future<void> submitRating({
    required String orderId,
    required String driverId,
    required int rating,
  }) async {
    await _db.collection('orders').doc(orderId).update({
      'rating': rating,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final snapshot = await _db
        .collection('orders')
        .where('driver_id', isEqualTo: driverId)
        .get();

    final ratings = snapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .where((order) =>
            order.status == OrderStatus.completed && order.rating != null)
        .map((order) => order.rating!)
        .toList();

    if (ratings.isEmpty) return;

    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    await _db.collection('users').doc(driverId).set({
      'rating_avg': avg,
      'rating_count': ratings.length,
    }, SetOptions(merge: true));
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