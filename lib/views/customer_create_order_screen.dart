import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/order_service.dart';
import '../services/routing_service.dart';
import '../services/pricing_service.dart';
import 'customer_map_picker_screen.dart';
import 'customer_waiting_screen.dart';

// farell: dummy customer id sementara, nanti diganti FirebaseAuth UID setelah login dibuat
const String kDummyCustomerId = 'customer_test_001';

class CustomerCreateOrderScreen extends StatefulWidget {
  const CustomerCreateOrderScreen({super.key});

  @override
  State<CustomerCreateOrderScreen> createState() =>
      _CustomerCreateOrderScreenState();
}

class _CustomerCreateOrderScreenState extends State<CustomerCreateOrderScreen> {
  final OrderService _orderService = OrderService();
  final PricingService _pricingService = PricingService();
  final RoutingService _routingService = RoutingService();
  final _formKey = GlobalKey<FormState>();

  final _itemDescriptionCtrl = TextEditingController();

  // data harga & kategori
  List<WeightCategory> _categories = [];
  WeightCategory? _selectedCategory;
  double? _costPerKm;

  // hasil dari map picker
  String? _pickupAddress;
  double? _pickupLat;
  double? _pickupLng;
  String? _destinationAddress;
  double? _destinationLat;
  double? _destinationLng;
  double? _distanceKm;
  double? _totalCost;

  bool _isLoadingConfig = true;
  String? _configError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPricingConfig();
  }

  @override
  void dispose() {
    _itemDescriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPricingConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _configError = null;
    });

    try {
      final results = await Future.wait([
        _pricingService.getCostPerKm(),
        _pricingService.getWeightCategories(),
      ]);

      if (!mounted) return;
      setState(() {
        _costPerKm = results[0] as double;
        _categories = results[1] as List<WeightCategory>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _configError = 'Gagal memuat data harga: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  void _recalculateCost() {
    if (_distanceKm != null &&
        _selectedCategory != null &&
        _costPerKm != null) {
      final baseCost = _distanceKm! * _costPerKm!;
      _totalCost = baseCost + _selectedCategory!.additionalCost;
    } else {
      _totalCost = null;
    }
  }

  Future<void> _refreshDistanceAndCost() async {
    if (_pickupLat == null ||
        _pickupLng == null ||
        _destinationLat == null ||
        _destinationLng == null) {
      setState(() {
        _distanceKm = null;
        _recalculateCost();
      });
      return;
    }

    try {
      final routeInfo = await _routingService.getRouteInfo(
        LatLng(_pickupLat!, _pickupLng!),
        LatLng(_destinationLat!, _destinationLng!),
      );
      if (!mounted) return;
      setState(() {
        _distanceKm = routeInfo.distanceMeters / 1000;
        _recalculateCost();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _distanceKm = null;
        _recalculateCost();
      });
      _showSnack('Gagal menghitung jarak: $e');
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CustomerMapPickerScreen(
          initialPickup: _pickupLat == null || _pickupLng == null
              ? null
              : LatLng(_pickupLat!, _pickupLng!),
          initialDestination: _destinationLat == null || _destinationLng == null
              ? null
              : LatLng(_destinationLat!, _destinationLng!),
        ),
      ),
    );

    if (result == null || !mounted) return;

    final pickupAddress = (result['pickup_address'] as String?)?.trim();
    final pickupLat = result['pickup_lat'] as double?;
    final pickupLng = result['pickup_lng'] as double?;
    final destAddress = (result['dest_address'] as String?)?.trim();
    final destLat = result['dest_lat'] as double?;
    final destLng = result['dest_lng'] as double?;

    if (pickupAddress == null ||
        pickupAddress.isEmpty ||
        pickupLat == null ||
        pickupLng == null ||
        destAddress == null ||
        destAddress.isEmpty ||
        destLat == null ||
        destLng == null) {
      return;
    }

    setState(() {
      _pickupAddress = pickupAddress;
      _pickupLat = pickupLat;
      _pickupLng = pickupLng;
      _destinationAddress = destAddress;
      _destinationLat = destLat;
      _destinationLng = destLng;
    });

    await _refreshDistanceAndCost();
  }

  bool get _isReadyToSubmit =>
      _pickupLat != null &&
      _pickupLng != null &&
      _destinationLat != null &&
      _destinationLng != null &&
      _distanceKm != null &&
      _totalCost != null &&
      _selectedCategory != null &&
      !_isSubmitting &&
      !_isLoadingConfig;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_pickupLat == null || _pickupLng == null) {
      _showSnack('Silakan pilih lokasi pickup & tujuan di peta terlebih dulu');
      return;
    }
    if (_destinationLat == null || _destinationLng == null) {
      _showSnack('Silakan pilih lokasi pickup & tujuan di peta terlebih dulu');
      return;
    }
    if (_selectedCategory == null) {
      _showSnack('Silakan pilih kategori berat');
      return;
    }
    if (_distanceKm == null || _totalCost == null) {
      _showSnack('Jarak/biaya belum terhitung. Pilih ulang lokasi di peta.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newOrderId = await _orderService.createOrder(
        customerId: kDummyCustomerId,
        pickupAddress: _pickupAddress?.trim() ?? '',
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        destAddress: _destinationAddress?.trim() ?? '',
        destLat: _destinationLat!,
        destLng: _destinationLng!,
        itemDescription: _itemDescriptionCtrl.text.trim(),
        weightCategoryId: _selectedCategory!.id,
        distanceKm: _distanceKm!,
        totalCost: _totalCost!,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerWaitingScreen(orderId: newOrderId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal membuat order: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Wajib diisi';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Order'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator())
          : _configError != null
          ? _buildConfigError()
          : _buildForm(),
    );
  }

  Widget _buildConfigError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 12),
            Text(_configError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPricingConfig,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Lokasi & Biaya'),
          _buildLocationSummary(
            'Pickup Address',
            _pickupAddress,
            _pickupLat,
            _pickupLng,
            accent: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildLocationSummary(
            'Destination Address',
            _destinationAddress,
            _destinationLat,
            _destinationLng,
            accent: Colors.red,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMapPicker,
              icon: const Icon(Icons.map),
              label: const Text('Pilih Lokasi di Peta'),
            ),
          ),
          const SizedBox(height: 16),
          _buildReadOnlyRow(
            'Jarak',
            _distanceKm == null ? '-' : '${_distanceKm!.toStringAsFixed(2)} km',
          ),
          _buildReadOnlyRow(
            'Total Biaya',
            _totalCost == null ? '-' : 'Rp ${_totalCost!.toStringAsFixed(0)}',
            highlight: true,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Detail Barang'),
          _buildTextField(
            controller: _itemDescriptionCtrl,
            label: 'Deskripsi Barang',
            validator: _validateRequired,
          ),
          DropdownButtonFormField<WeightCategory>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategori Berat',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _categories
                .map(
                  (cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(
                      '${cat.name} (+Rp ${cat.additionalCost.toStringAsFixed(0)})',
                    ),
                  ),
                )
                .toList(),
            validator: (value) => value == null ? 'Pilih kategori berat' : null,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _recalculateCost();
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isReadyToSubmit ? _submit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Buat Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLocationSummary(
    String label,
    String? address,
    double? lat,
    double? lng, {
    Color? accent,
  }) {
    final hasValue = address != null && lat != null && lng != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      tileColor: accent?.withValues(alpha: 0.08) ?? Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: accent ?? Colors.black87,
        ),
      ),
      subtitle: Text(hasValue ? address : 'Belum dipilih'),
      isThreeLine: false,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              fontSize: highlight ? 16 : 14,
              color: highlight ? Theme.of(context).colorScheme.secondary : null,
            ),
          ),
        ],
      ),
    );
  }
}
