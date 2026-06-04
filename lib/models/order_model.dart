import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum OrderStatus {
  pending,
  accepted,
  pickingUp,
  delivering,
  completed,
  cancelled,
}

class OrderModel {
  final String orderId;

  final String customerId;
  final String? driverId;
  final String? weightCategoryId;

  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final LatLng? driverLocation;

  final String pickupAddress;
  final String destinationAddress;
  final String itemDescription;

  final double distanceKm;
  final double totalCost;

  final String proofPhotoUrl;

  OrderStatus status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.orderId,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.status,
    this.customerId = '',
    this.driverId,
    this.weightCategoryId,
    this.driverLocation,
    this.itemDescription = '',
    this.distanceKm = 0.0,
    this.totalCost = 0.0,
    this.proofPhotoUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final driverLat = (data['driver_lat'] as num?)?.toDouble();
    final driverLng = (data['driver_lng'] as num?)?.toDouble();

    return OrderModel(
      orderId: doc.id,

      customerId: data['customer_id'] as String? ?? '',
      driverId: data['driver_id'] as String?,
      weightCategoryId: data['weight_category_id'] as String?,

      pickupLocation: LatLng(
        (data['pickup_lat'] as num?)?.toDouble() ?? 0.0,
        (data['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      ),

      destinationLocation: LatLng(
        (data['dest_lat'] as num?)?.toDouble() ?? 0.0,
        (data['dest_lng'] as num?)?.toDouble() ?? 0.0,
      ),

      driverLocation: driverLat != null && driverLng != null
          ? LatLng(driverLat, driverLng)
          : null,

      pickupAddress: data['pickup_address'] as String? ?? 'Lokasi Jemput',
      destinationAddress: data['dest_address'] as String? ?? 'Lokasi Tujuan',
      itemDescription: data['item_description'] as String? ?? '',

      distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
      totalCost: (data['total_cost'] as num?)?.toDouble() ?? 0.0,

      proofPhotoUrl: data['proof_photo_url'] as String? ?? '',

      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),

      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }
}