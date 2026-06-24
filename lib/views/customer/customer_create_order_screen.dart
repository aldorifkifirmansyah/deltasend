import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/order_service.dart';
import '../../services/pricing_service.dart';
import '../../services/routing_service.dart';
import '../../utils/app_assets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'customer_map_picker_screen.dart';
import 'customer_waiting_screen.dart';

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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _itemDescriptionCtrl = TextEditingController();

  List<WeightCategory> _categories = [];
  WeightCategory? _selectedCategory;
  double? _costPerKm;

  String? _pickupAddress;
  double? _pickupLat;
  double? _pickupLng;

  String? _destinationAddress;
  double? _destinationLat;
  double? _destinationLng;

  double? _distanceKm;
  double? _totalCost;

  bool _isLoadingConfig = true;
  bool _isSubmitting = false;
  String? _configError;

  int _currentStep = 1;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _pickupBlue = Color(0xFF133D87);
  static const Color _destinationRed = Color(0xFFFF4A45);

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
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _configError = 'Gagal memuat konfigurasi harga: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  void _recalculateCost() {
    if (_distanceKm != null &&
        _selectedCategory != null &&
        _costPerKm != null) {
      final double baseCost = _distanceKm! * _costPerKm!;

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
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _distanceKm = null;
        _recalculateCost();
      });

      _showSnack('Gagal menghitung jarak: $error');
    }
  }

  Future<void> _openMapPicker() async {
    final Map<String, dynamic>? result = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => CustomerMapPickerScreen(
              initialPickup: _pickupLat == null || _pickupLng == null
                  ? null
                  : LatLng(_pickupLat!, _pickupLng!),
              initialDestination:
                  _destinationLat == null || _destinationLng == null
                  ? null
                  : LatLng(_destinationLat!, _destinationLng!),
            ),
          ),
        );

    if (result == null || !mounted) return;

    final String? pickupAddress = (result['pickup_address'] as String?)?.trim();
    final double? pickupLat = result['pickup_lat'] as double?;
    final double? pickupLng = result['pickup_lng'] as double?;

    final String? destinationAddress = (result['dest_address'] as String?)
        ?.trim();
    final double? destinationLat = result['dest_lat'] as double?;
    final double? destinationLng = result['dest_lng'] as double?;

    if (pickupAddress == null ||
        pickupAddress.isEmpty ||
        pickupLat == null ||
        pickupLng == null ||
        destinationAddress == null ||
        destinationAddress.isEmpty ||
        destinationLat == null ||
        destinationLng == null) {
      _showSnack('Data lokasi belum lengkap.');
      return;
    }

    setState(() {
      _pickupAddress = pickupAddress;
      _pickupLat = pickupLat;
      _pickupLng = pickupLng;

      _destinationAddress = destinationAddress;
      _destinationLat = destinationLat;
      _destinationLng = destinationLng;

      _currentStep = 2;
    });

    await _refreshDistanceAndCost();
  }

  bool get _hasItemData =>
      _itemDescriptionCtrl.text.trim().isNotEmpty && _selectedCategory != null;

  bool get _hasLocationData =>
      _pickupLat != null &&
      _pickupLng != null &&
      _destinationLat != null &&
      _destinationLng != null;

  bool get _isReadyToSubmit =>
      _hasItemData &&
      _hasLocationData &&
      _distanceKm != null &&
      _totalCost != null &&
      !_isSubmitting &&
      !_isLoadingConfig;

  void _continueToLocation() {
    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) return;

    setState(() {
      _currentStep = 2;
    });

    _openMapPicker();
  }

  void _continueToConfirmation() {
    if (!_hasItemData) {
      _showSnack('Lengkapi detail barang terlebih dahulu.');
      setState(() {
        _currentStep = 1;
      });
      return;
    }

    if (!_hasLocationData) {
      _showSnack('Pilih lokasi pickup dan tujuan.');
      setState(() {
        _currentStep = 2;
      });
      return;
    }

    if (_distanceKm == null || _totalCost == null) {
      _showSnack('Jarak dan biaya belum berhasil dihitung.');
      return;
    }

    setState(() {
      _currentStep = 3;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      setState(() {
        _currentStep = 1;
      });
      return;
    }

    if (!_hasLocationData ||
        _distanceKm == null ||
        _totalCost == null ||
        _selectedCategory == null) {
      _showSnack('Data order belum lengkap.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String customerId =
          context.read<AuthViewModel>().currentUser?.uid ?? '';

      if (customerId.isEmpty) {
        throw Exception('Customer tidak ditemukan.');
      }

      final String newOrderId = await _orderService.createOrder(
        customerId: customerId,
        pickupAddress: _pickupAddress!.trim(),
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        destAddress: _destinationAddress!.trim(),
        destLat: _destinationLat!,
        destLng: _destinationLng!,
        itemDescription: _itemDescriptionCtrl.text.trim(),
        weightCategoryId: _selectedCategory!.id,
        weightCategoryName: _selectedCategory!.name,
        distanceKm: _distanceKm!,
        totalCost: _totalCost!,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerWaitingScreen(orderId: newOrderId),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showSnack('Gagal membuat order: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateItemDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Deskripsi barang wajib diisi';
    }

    if (value.trim().length < 3) {
      return 'Deskripsi barang minimal 3 karakter';
    }

    return null;
  }

  String _formatCurrency(double value) {
    final String raw = value.toStringAsFixed(0);
    final StringBuffer result = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final int reverseIndex = raw.length - i;

      result.write(raw[i]);

      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        result.write('.');
      }
    }

    return 'Rp. $result';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return const ColoredBox(color: Color(0xFFF7F9FC));
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                SvgPicture.asset(AppAssets.logo, width: 214),
                const SizedBox(height: 28),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingConfig) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryBlue),
      );
    }

    if (_configError != null) {
      return _buildConfigError();
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 26),
          _buildStepIndicator(),
          const SizedBox(height: 30),
          _buildCurrentStep(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep -= 1;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textDark,
            size: 25,
          ),
        ),
        Expanded(
          child: Text(
            'Add Order',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepItem(
          number: 1,
          label: 'Barang',
          active: _currentStep == 1,
          completed: _currentStep > 1,
          onTap: () {
            setState(() {
              _currentStep = 1;
            });
          },
        ),
        const Expanded(child: Divider(thickness: 1, color: Color(0xFFD5DDE8))),
        _StepItem(
          number: 2,
          label: 'Lokasi',
          active: _currentStep == 2,
          completed: _currentStep > 2,
          onTap: () {
            if (_hasItemData) {
              setState(() {
                _currentStep = 2;
              });
            }
          },
        ),
        const Expanded(child: Divider(thickness: 1, color: Color(0xFFD5DDE8))),
        _StepItem(
          number: 3,
          label: 'Konfirmasi',
          active: _currentStep == 3,
          completed: false,
          onTap: () {
            if (_isReadyToSubmit) {
              setState(() {
                _currentStep = 3;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildItemStep();
      case 2:
        return _buildLocationStep();
      case 3:
        return _buildConfirmationStep();
      default:
        return _buildItemStep();
    }
  }

  Widget _buildItemStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detail Barang',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Deskripsi Barang',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _itemDescriptionCtrl,
          minLines: 3,
          maxLines: 5,
          validator: _validateItemDescription,
          onChanged: (_) {
            setState(() {});
          },
          style: GoogleFonts.inter(color: _textDark, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Contoh: Dokumen, pakaian, makanan, atau barang lainnya',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFFA1A9B5),
              fontSize: 13,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kategori Berat',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<WeightCategory>(
          initialValue: _selectedCategory,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
            ),
          ),
          hint: Text(
            'Pilih kategori berat',
            style: GoogleFonts.inter(
              color: const Color(0xFFA1A9B5),
              fontSize: 14,
            ),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem<WeightCategory>(
              value: category,
              child: Text(
                '${category.name}  (+${_formatCurrency(category.additionalCost)})',
                style: GoogleFonts.inter(color: _textDark, fontSize: 13.5),
              ),
            );
          }).toList(),
          validator: (value) {
            if (value == null) {
              return 'Pilih kategori berat';
            }

            return null;
          },
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
              _recalculateCost();
            });
          },
        ),
        const SizedBox(height: 30),
        _PrimaryButton(
          label: 'Lanjut Pilih Lokasi',
          icon: Icons.arrow_forward_rounded,
          enabled: !_isSubmitting,
          onPressed: _continueToLocation,
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lokasi Penjemputan (Pickup)',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _LocationCard(
          icon: Icons.location_on_outlined,
          iconColor: _pickupBlue,
          title: _pickupAddress == null
              ? 'Pilih lokasi pickup'
              : 'Lokasi Pickup',
          address: _pickupAddress ?? 'Lokasi belum dipilih',
          onEdit: _openMapPicker,
        ),
        const SizedBox(height: 20),
        Text(
          'Lokasi Pengantaran (Drop-off)',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _LocationCard(
          icon: Icons.location_on_rounded,
          iconColor: _destinationRed,
          title: _destinationAddress == null
              ? 'Pilih lokasi tujuan'
              : 'Lokasi Tujuan',
          address: _destinationAddress ?? 'Lokasi belum dipilih',
          onEdit: _openMapPicker,
        ),
        if (_distanceKm != null) ...[
          const SizedBox(height: 22),
          _InformationRow(
            label: 'Jarak Pengiriman',
            value: '${_distanceKm!.toStringAsFixed(2)} km',
          ),
        ],
        const SizedBox(height: 30),
        _PrimaryButton(
          label: _hasLocationData ? 'Konfirmasi' : 'Pilih Lokasi di Peta',
          icon: _hasLocationData ? Icons.check_rounded : Icons.map_outlined,
          enabled: true,
          onPressed: _hasLocationData
              ? _continueToConfirmation
              : _openMapPicker,
        ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCard(
          orderIdLabel: 'Order akan dibuat',
          pickupAddress: _pickupAddress ?? 'Belum dipilih',
          destinationAddress: _destinationAddress ?? 'Belum dipilih',
          itemDescription: _itemDescriptionCtrl.text.trim(),
          weightLabel: _selectedCategory?.name ?? '-',
          distanceLabel: _distanceKm == null
              ? '-'
              : '${_distanceKm!.toStringAsFixed(2)} km',
          totalCostLabel: _totalCost == null
              ? '-'
              : _formatCurrency(_totalCost!),
        ),
        const SizedBox(height: 20),
        Text(
          'Metode Pembayaran',
          style: GoogleFonts.inter(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderBlue),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: _primaryBlue,
                size: 23,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tunai (${_totalCost == null ? '-' : _formatCurrency(_totalCost!)})',
                  style: GoogleFonts.inter(
                    color: _textGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Buat Order',
          icon: Icons.local_shipping_outlined,
          enabled: _isReadyToSubmit,
          loading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildConfigError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD14343),
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _configError ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textGrey,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadPricingConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Coba Lagi',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool completed;
  final VoidCallback onTap;

  const _StepItem({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color circleColor = active || completed
        ? const Color(0xFF133D87)
        : Colors.white;

    final Color foregroundColor = active || completed
        ? Colors.white
        : const Color(0xFF9BA6B6);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: active || completed
                    ? const Color(0xFF133D87)
                    : const Color(0xFFB9C4D3),
              ),
            ),
            child: completed
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Text(
                    '$number',
                    style: GoogleFonts.inter(
                      color: foregroundColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: active ? const Color(0xFF1A1D23) : const Color(0xFF8B96A6),
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String address;
  final VoidCallback onEdit;

  const _LocationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.address,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC5D8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A1D23),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7A8493),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_rounded,
              color: Color(0xFF7B7B7B),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;

  const _InformationRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF6F7784),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFF1A1D23),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String orderIdLabel;
  final String pickupAddress;
  final String destinationAddress;
  final String itemDescription;
  final String weightLabel;
  final String distanceLabel;
  final String totalCostLabel;

  const _SummaryCard({
    required this.orderIdLabel,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.itemDescription,
    required this.weightLabel,
    required this.distanceLabel,
    required this.totalCostLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC5D8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ringkasan Order',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A1D23),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                orderIdLabel,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0AAA55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryAddress(
            label: 'Pickup',
            address: pickupAddress,
            labelColor: const Color(0xFF0066FF),
          ),
          const SizedBox(height: 14),
          _SummaryAddress(
            label: 'Tujuan',
            address: destinationAddress,
            labelColor: const Color(0xFF0AAA55),
          ),
          const Divider(height: 28, color: Color(0xFFE5E9EF)),
          _SummaryValue(label: 'Barang', value: itemDescription),
          const SizedBox(height: 10),
          _SummaryValue(label: 'Kategori Berat', value: weightLabel),
          const SizedBox(height: 10),
          _SummaryValue(label: 'Jarak', value: distanceLabel),
          const SizedBox(height: 10),
          _SummaryValue(label: 'Ongkir', value: totalCostLabel),
          const Divider(height: 24, color: Color(0xFFE5E9EF)),
          _SummaryValue(
            label: 'Total Pembayaran',
            value: totalCostLabel,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryAddress extends StatelessWidget {
  final String label;
  final String address;
  final Color labelColor;

  const _SummaryAddress({
    required this.label,
    required this.address,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: labelColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address,
          style: GoogleFonts.inter(
            color: const Color(0xFF6F7784),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryValue({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF6F7784),
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1D23),
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: enabled && !loading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF133D87),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(
            0xFF133D87,
          ).withValues(alpha: 0.45),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 19),
                ],
              ),
      ),
    );
  }
}
