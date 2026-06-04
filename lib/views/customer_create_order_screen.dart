import 'package:flutter/material.dart';
import '../services/order_service.dart';

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
  final _formKey = GlobalKey<FormState>();

  final _pickupAddressCtrl = TextEditingController();
  final _pickupLatCtrl = TextEditingController();
  final _pickupLngCtrl = TextEditingController();
  final _destAddressCtrl = TextEditingController();
  final _destLatCtrl = TextEditingController();
  final _destLngCtrl = TextEditingController();
  final _itemDescriptionCtrl = TextEditingController();
  final _weightCategoryCtrl = TextEditingController();
  final _distanceKmCtrl = TextEditingController();
  final _totalCostCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _pickupAddressCtrl.dispose();
    _pickupLatCtrl.dispose();
    _pickupLngCtrl.dispose();
    _destAddressCtrl.dispose();
    _destLatCtrl.dispose();
    _destLngCtrl.dispose();
    _itemDescriptionCtrl.dispose();
    _weightCategoryCtrl.dispose();
    _distanceKmCtrl.dispose();
    _totalCostCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _pickupAddressCtrl.clear();
    _pickupLatCtrl.clear();
    _pickupLngCtrl.clear();
    _destAddressCtrl.clear();
    _destLatCtrl.clear();
    _destLngCtrl.clear();
    _itemDescriptionCtrl.clear();
    _weightCategoryCtrl.clear();
    _distanceKmCtrl.clear();
    _totalCostCtrl.clear();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final orderId = await _orderService.createOrder(
        customerId: kDummyCustomerId,
        pickupAddress: _pickupAddressCtrl.text.trim(),
        pickupLat: double.parse(_pickupLatCtrl.text.trim()),
        pickupLng: double.parse(_pickupLngCtrl.text.trim()),
        destAddress: _destAddressCtrl.text.trim(),
        destLat: double.parse(_destLatCtrl.text.trim()),
        destLng: double.parse(_destLngCtrl.text.trim()),
        itemDescription: _itemDescriptionCtrl.text.trim(),
        weightCategoryId: _weightCategoryCtrl.text.trim().isEmpty
            ? null
            : _weightCategoryCtrl.text.trim(),
        distanceKm: double.tryParse(_distanceKmCtrl.text.trim()) ?? 0.0,
        totalCost: double.tryParse(_totalCostCtrl.text.trim()) ?? 0.0,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Wajib diisi';
    }
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Wajib diisi';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Harus berupa angka';
    }
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Lokasi Penjemputan'),
            _buildTextField(
              controller: _pickupAddressCtrl,
              label: 'Alamat Jemput',
              validator: _validateRequired,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _pickupLatCtrl,
                    label: 'Pickup Lat',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _validateNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _pickupLngCtrl,
                    label: 'Pickup Lng',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _validateNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSectionTitle('Lokasi Tujuan'),
            _buildTextField(
              controller: _destAddressCtrl,
              label: 'Alamat Tujuan',
              validator: _validateRequired,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _destLatCtrl,
                    label: 'Dest Lat',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _validateNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _destLngCtrl,
                    label: 'Dest Lng',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _validateNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSectionTitle('Detail Barang'),
            _buildTextField(
              controller: _itemDescriptionCtrl,
              label: 'Deskripsi Barang',
              validator: _validateRequired,
            ),
            _buildTextField(
              controller: _weightCategoryCtrl,
              label: 'Weight Category ID (opsional)',
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _distanceKmCtrl,
                    label: 'Jarak (km)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validateNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _totalCostCtrl,
                    label: 'Total Biaya (Rp)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validateNumber,
                  ),
                ),
              ],
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
                onPressed: _isSubmitting ? null : _submit,
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
