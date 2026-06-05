import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';

enum _LocationType { pickup, destination }

class CustomerMapPickerScreen extends StatefulWidget {
  final LatLng? initialPickup;
  final LatLng? initialDestination;
  final String? initialType;

  const CustomerMapPickerScreen({
    super.key,
    this.initialPickup,
    this.initialDestination,
    this.initialType,
  });

  @override
  State<CustomerMapPickerScreen> createState() =>
      _CustomerMapPickerScreenState();
}

class _CustomerMapPickerScreenState extends State<CustomerMapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  static const LatLng _defaultCenter = LatLng(-8.1689, 113.7022);

  LatLng? _selectedPoint;
  String? _selectedAddressText;
  _LocationType _selectedType = _LocationType.pickup;

  String? _pickupAddress;
  double? _pickupLat;
  double? _pickupLng;
  String? _destinationAddress;
  double? _destinationLat;
  double? _destinationLng;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingAddress = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    if (widget.initialPickup != null) {
      _pickupLat = widget.initialPickup!.latitude;
      _pickupLng = widget.initialPickup!.longitude;
      _pickupAddress = 'Lokasi pickup terpilih';
    }
    if (widget.initialDestination != null) {
      _destinationLat = widget.initialDestination!.latitude;
      _destinationLng = widget.initialDestination!.longitude;
      _destinationAddress = 'Lokasi tujuan terpilih';
    }

    if (widget.initialType == 'destination') {
      _selectedType = _LocationType.destination;
    }
    _selectedPoint = widget.initialType == 'destination'
        ? widget.initialDestination ?? widget.initialPickup
        : widget.initialPickup ?? widget.initialDestination;
    if (_selectedType == _LocationType.pickup && _pickupAddress != null) {
      _selectedAddressText = _pickupAddress;
    } else if (_selectedType == _LocationType.destination &&
        _destinationAddress != null) {
      _selectedAddressText = _destinationAddress;
    }
    _addressController.text = _selectedAddressText ?? '';

    if (_selectedPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.move(_selectedPoint!, 15.0);
        } catch (_) {}
      });
    }

    _initCurrentLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _addressController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final loc = LatLng(pos.latitude, pos.longitude);

      if (_selectedPoint == null) {
        try {
          _mapController.move(loc, 15.0);
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _syncActiveSelection(String address, double lat, double lng) {
    setState(() {
      _selectedAddressText = address;
      _addressController.text = address;

      if (_selectedType == _LocationType.pickup) {
        _pickupAddress = address;
        _pickupLat = lat;
        _pickupLng = lng;
      } else {
        _destinationAddress = address;
        _destinationLat = lat;
        _destinationLng = lng;
      }
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _searchError = null;
      });

      try {
        final results = await GeocodingService.searchAddress(query);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _searchError = results.isEmpty ? 'Alamat tidak ditemukan' : null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = 'Gagal mencari alamat: $e';
        });
      }
    });
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _searchResults = [];
      _searchError = null;
      _searchController.clear();
      _isLoadingAddress = true;
    });

    try {
      _mapController.move(point, 16.0);
    } catch (_) {}

    try {
      final address = await GeocodingService.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (!mounted) return;

      final resolvedAddress = (address?.trim().isNotEmpty == true)
          ? address!.trim()
          : 'Lokasi dipilih';
      _syncActiveSelection(resolvedAddress, point.latitude, point.longitude);
      setState(() => _searchError = null);
    } catch (e) {
      if (!mounted) return;
      final fallbackAddress = 'Lokasi dipilih';
      _syncActiveSelection(fallbackAddress, point.latitude, point.longitude);
      setState(() {
        _searchError = 'Gagal mengambil alamat: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _onSearchResultSelected(Map<String, dynamic> result) {
    final lat = result['lat'] as double?;
    final lng = result['lon'] as double?;
    final address = (result['display_name'] as String?)?.trim();

    if (lat == null || lng == null) {
      return;
    }

    final point = LatLng(lat, lng);
    setState(() {
      _selectedPoint = point;
      _searchResults = [];
      _searchError = null;
      _searchController.clear();
    });

    final resolvedAddress = address?.isNotEmpty == true
        ? address!
      : 'Lokasi terpilih';
    _syncActiveSelection(resolvedAddress, lat, lng);

    _searchFocusNode.unfocus();

    try {
      _mapController.move(point, 16.0);
    } catch (_) {}
  }

  void _confirm() {
    if (_pickupLat == null ||
        _pickupLng == null ||
        _destinationLat == null ||
        _destinationLng == null) {
      return;
    }
    Navigator.of(context).pop({
      'pickup_address': _pickupAddress,
      'pickup_lat': _pickupLat,
      'pickup_lng': _pickupLng,
      'dest_address': _destinationAddress,
      'dest_lat': _destinationLat,
      'dest_lng': _destinationLng,
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        _pickupLat != null &&
        _pickupLng != null &&
        _destinationLat != null &&
        _destinationLng != null &&
        _addressController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint ?? _defaultCenter,
              initialZoom: 14.0,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.deltasend.app',
              ),
              MarkerLayer(
                markers: [
                  if (_pickupLat != null && _pickupLng != null)
                    Marker(
                      point: LatLng(_pickupLat!, _pickupLng!),
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.my_location,
                        color: Colors.green,
                        size: 36,
                      ),
                    ),
                  if (_destinationLat != null && _destinationLng != null)
                    Marker(
                      point: LatLng(_destinationLat!, _destinationLng!),
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: AnimatedBuilder(
              animation: _searchFocusNode,
              builder: (context, _) {
                final showResults = _searchController.text.trim().isNotEmpty;
                final focused = _searchFocusNode.hasFocus;

                return Material(
                  elevation: focused || showResults ? 10 : 6,
                  shadowColor: Colors.black26,
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: focused
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildModeButton(
                                    label: 'Pickup',
                                    icon: Icons.my_location,
                                    active:
                                        _selectedType == _LocationType.pickup,
                                    color: Colors.green,
                                    onTap: () => setState(
                                      () => _selectedType =
                                          _LocationType.pickup,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildModeButton(
                                    label: 'Destination',
                                    icon: Icons.flag,
                                    active: _selectedType ==
                                        _LocationType.destination,
                                    color: Colors.red,
                                    onTap: () => setState(
                                      () => _selectedType =
                                          _LocationType.destination,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (value) {
                                setState(() {});
                                _onSearchChanged(value);
                              },
                              decoration: InputDecoration(
                                hintText: 'Cari alamat atau tempat',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? (_isLoadingAddress
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : null)
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 1.4,
                                  ),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (!showResults &&
                              _selectedPoint == null &&
                              !_searchFocusNode.hasFocus)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                _selectedPoint == null &&
                                        _searchController.text.isEmpty
                                    ? 'Tap peta atau pilih hasil pencarian'
                                    : '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                        if (_selectedPoint != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              _selectedAddressText ?? 'Tap untuk memilih lokasi',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: showResults
                                ? ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          _searchResults.isEmpty ||
                                                  _isSearching
                                              ? 120
                                              : (_searchResults.length >= 5
                                                    ? 280
                                                    : 64.0 +
                                                        (_searchResults
                                                                .length *
                                                            64.0)),
                                    ),
                                    child: _buildSearchResultsPanel(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Konfirmasi lokasi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Label alamat',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryChip(
                            label: 'Type',
                            value: _selectedType == _LocationType.pickup
                                ? 'Pickup'
                                : 'Destination',
                            color: _selectedType == _LocationType.pickup
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationPreview(
                            'Pickup',
                            _pickupAddress,
                            _pickupLat,
                            _pickupLng,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLocationPreview(
                            'Destination',
                            _destinationAddress,
                            _destinationLat,
                            _destinationLng,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (_isSearching) ...[
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Mencari alamat...'),
                        ],
                      ),
                    ] else if (_isLoadingAddress) ...[
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Mengambil alamat lokasi...'),
                        ],
                      ),
                    ] else if (_searchError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _searchError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: canConfirm ? _confirm : null,
                        child: const Text(
                          'Gunakan Lokasi Ini',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsPanel() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _searchError ?? 'Tidak ada hasil pencarian',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final title = (result['display_name'] as String?) ?? 'Alamat';

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.north_east, size: 18),
          onTap: () => _onSearchResultSelected(result),
        );
      },
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.1) ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color ?? Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLocationPreview(
    String label,
    String? address,
    double? lat,
    double? lng,
    Color color,
  ) {
    final hasValue = address != null && lat != null && lng != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasValue ? address : 'Belum dipilih',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool active,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? color.shade50 : null,
          foregroundColor: active ? color : null,
          side: BorderSide(color: active ? color : Colors.grey),
        ),
      ),
    );
  }
}
