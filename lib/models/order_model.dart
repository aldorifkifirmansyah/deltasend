import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum OrderStatus { pickingUp, delivering, completed }

class OrderModel {
  final String orderId;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final String pickupAddress;
  final String destinationAddress;
  OrderStatus status;

  OrderModel({
    required this.orderId,
    required this.pickupLocation,
    required this.destinationLocation,
    this.pickupAddress = 'Lokasi Penjemputan',
    this.destinationAddress = 'Lokasi Pengiriman',
    this.status = OrderStatus.pickingUp,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    return OrderModel(
      orderId: doc.id,
      pickupLocation: LatLng(
        (data?['pickup_lat'] as num?)?.toDouble() ?? 0.0,
        (data?['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      ),
      destinationLocation: LatLng(
        (data?['dest_lat'] as num?)?.toDouble() ?? 0.0,
        (data?['dest_lng'] as num?)?.toDouble() ?? 0.0,
      ),
      pickupAddress: data?['pickup_address'] as String? ?? 'Lokasi Jemput',
      destinationAddress: data?['dest_address'] as String? ?? 'Lokasi Tujuan',
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data?['status'],
        orElse: () => OrderStatus.pickingUp,
      ),
    );
  }
}
