import 'package:cloud_firestore/cloud_firestore.dart';

// farell: model ringan buat dropdown kategori berat
class WeightCategory {
  final String id;
  final String name;
  final double additionalCost;

  WeightCategory({
    required this.id,
    required this.name,
    required this.additionalCost,
  });

  factory WeightCategory.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WeightCategory(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      additionalCost: (data['additional_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PricingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ambil cost_per_km dari pricing_config/default
  Future<double> getCostPerKm() async {
    final doc = await _db.collection('pricing_config').doc('default').get();

    if (!doc.exists) {
      throw Exception('Dokumen pricing_config/default tidak ditemukan');
    }

    final data = doc.data() ?? {};
    final costPerKm = (data['cost_per_km'] as num?)?.toDouble();

    if (costPerKm == null) {
      throw Exception('Field cost_per_km tidak ada di pricing_config/default');
    }

    return costPerKm;
  }

  // ambil semua kategori berat buat dropdown
  Future<List<WeightCategory>> getWeightCategories() async {
    final snapshot = await _db.collection('weight_categories').get();

    if (snapshot.docs.isEmpty) {
      throw Exception('Koleksi weight_categories kosong / tidak ada data');
    }

    return snapshot.docs.map((doc) => WeightCategory.fromDoc(doc)).toList();
  }
}
