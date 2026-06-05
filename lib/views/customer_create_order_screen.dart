import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/order_service.dart';
import '../services/pricing_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'customer_map_picker_screen.dart';

class CustomerCreateOrderScreen extends StatefulWidget {
  const CustomerCreateOrderScreen({super.key});

  @override
  State<CustomerCreateOrderScreen> createState() =>
      _CustomerCreateOrderScreenState();
}

class _CustomerCreateOrderScreenState extends State<CustomerCreateOrderScreen> {
  final OrderService _orderService = OrderService();
  final PricingService _pricingService = PricingService();
  final _formKey = GlobalKey<FormState>();

  final _pickupAddressCtrl = TextEditingController();
  final _destAddressCtrl = TextEditingController();
  final _itemDescriptionCtrl = TextEditingController();

  // data harga & kategori
  List<WeightCategory> _categories = [];
  WeightCategory? _selectedCategory;
  double? _costPerKm;

  // hasil dari map picker
  LatLng? _pickup;
  LatLng? _destination;
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
    _pickupAddressCtrl.dispose();
    _destAddressCtrl.dispose();
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
    if (_distanceKm != null && _selectedCategory != null && _costPerKm != null) {
      final baseCost = _distanceKm! * _costPerKm!;
      _totalCost = baseCost + _selectedCategory!.additionalCost;
    } else {
      _totalCost = null;
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => CustomerMapPickerScreen(
          initialPickup: _pickup,
          initialDestination: _destination,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _pickup = result.pickup;
      _destination = result.destination;
      _distanceKm = result.distanceMeters / 1000;
      _recalculateCost();
    });
  }

  bool get _isReadyToSubmit =>
      _pickup != null &&
      _destination != null &&
      _distanceKm != null &&
      _totalCost != null &&
      _selectedCategory != null &&
      !_isSubmitting &&
      !_isLoadingConfig;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_pickup == null || _destination == null) {
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
      final customerId =
          context.read<AuthViewModel>().currentUser?.uid ?? '';
      final orderId = await _orderService.createOrder(
        customerId: customerId,
        pickupAddress: _pickupAddressCtrl.text.trim(),
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        destAddress: _destAddressCtrl.text.trim(),
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
        itemDescription: _itemDescriptionCtrl.text.trim(),
        weightCategoryId: _selectedCategory!.id,
        distanceKm: _distanceKm!,
        totalCost: _totalCost!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order berhasil dibuat (id: $orderId)'),
          backgroundColor: Colors.green,
        ),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal membuat order: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _pickupAddressCtrl.clear();
    _destAddressCtrl.clear();
    _itemDescriptionCtrl.clear();
    setState(() {
      _selectedCategory = null;
      _pickup = null;
      _destination = null;
      _distanceKm = null;
      _totalCost = null;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          _buildSectionTitle('Alamat'),
          _buildTextField(
            controller: _pickupAddressCtrl,
            label: 'Nama/Alamat Jemput',
            validator: _validateRequired,
            helperText:
                'Titik koordinat jemput ditentukan lewat peta di bawah.',
          ),
          _buildTextField(
            controller: _destAddressCtrl,
            label: 'Nama/Alamat Tujuan',
            validator: _validateRequired,
            helperText:
                'Titik koordinat tujuan ditentukan lewat peta di bawah.',
          ),
          const SizedBox(height: 8),
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
            validator: (value) =>
                value == null ? 'Pilih kategori berat' : null,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _recalculateCost();
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Lokasi & Biaya'),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openMapPicker,
              icon: const Icon(Icons.map),
              label: Text(
                _pickup == null
                    ? 'Pilih Lokasi di Peta'
                    : 'Ubah Lokasi di Peta',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildReadOnlyRow(
            'Pickup',
            _pickup == null
                ? '-'
                : '${_pickup!.latitude.toStringAsFixed(5)}, ${_pickup!.longitude.toStringAsFixed(5)}',
          ),
          _buildReadOnlyRow(
            'Tujuan',
            _destination == null
                ? '-'
                : '${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}',
          ),
          _buildReadOnlyRow(
            'Jarak',
            _distanceKm == null
                ? '-'
                : '${_distanceKm!.toStringAsFixed(2)} km',
          ),
          _buildReadOnlyRow(
            'Total Biaya',
            _totalCost == null
                ? '-'
                : 'Rp ${_totalCost!.toStringAsFixed(0)}',
            highlight: true,
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

  Widget _buildReadOnlyRow(String label, String value,
      {bool highlight = false}) {
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
              color: highlight
                  ? Theme.of(context).colorScheme.secondary
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
