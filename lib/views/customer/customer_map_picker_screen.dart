import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../services/geocoding_service.dart';
import '../../widgets/location_status_banner.dart';

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

class _CustomerMapPickerScreenState extends State<CustomerMapPickerScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounceTimer;

  static const LatLng _defaultCenter = LatLng(-8.1724, 113.7003);

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textGrey = Color(0xFF6F7784);
  static const Color _borderBlue = Color(0xFFC5D8EE);
  static const Color _pickupBlue = Color(0xFF133D87);
  static const Color _destinationRed = Color(0xFFFF4A45);

  _LocationType _selectedType = _LocationType.pickup;

  LatLng? _selectedPoint;

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

  // null = lokasi normal/OK; selain itu tampilkan banner kuning persistent.
  LocationBannerState? _locationBanner;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

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

    _selectedPoint = _selectedType == _LocationType.destination
        ? widget.initialDestination ?? widget.initialPickup
        : widget.initialPickup ?? widget.initialDestination;

    if (_selectedPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          _mapController.move(_selectedPoint!, 15);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationStatus();
    }
  }

  // Re-check service+permission saat app resume; refresh banner kalau memang
  // sedang menampilkan masalah lokasi (jangan munculkan banner secara proaktif).
  Future<void> _checkLocationStatus() async {
    if (_locationBanner == null) return;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() => _locationBanner = LocationBannerState.serviceOff);
        return;
      }

      final LocationPermission permission =
          await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationBanner = LocationBannerState.deniedForever);
        return;
      }
      if (permission == LocationPermission.denied) {
        setState(() => _locationBanner = LocationBannerState.denied);
        return;
      }

      setState(() => _locationBanner = null);
    } catch (_) {
      // biarkan banner apa adanya kalau pengecekan gagal
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

  void _setLocationType(_LocationType type) {
    setState(() {
      _selectedType = type;

      if (type == _LocationType.pickup &&
          _pickupLat != null &&
          _pickupLng != null) {
        _selectedPoint = LatLng(_pickupLat!, _pickupLng!);
      }

      if (type == _LocationType.destination &&
          _destinationLat != null &&
          _destinationLng != null) {
        _selectedPoint = LatLng(_destinationLat!, _destinationLng!);
      }
    });

    if (_selectedPoint != null) {
      try {
        _mapController.move(_selectedPoint!, 16);
      } catch (_) {}
    }
  }

  void _syncSelection({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    setState(() {
      _selectedPoint = LatLng(latitude, longitude);

      if (_selectedType == _LocationType.pickup) {
        _pickupAddress = address;
        _pickupLat = latitude;
        _pickupLng = longitude;
      } else {
        _destinationAddress = address;
        _destinationLat = latitude;
        _destinationLng = longitude;
      }
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    final String query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 450), () async {
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
      } catch (error) {
        if (!mounted) return;

        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = 'Gagal mencari alamat';
        });
      }
    });
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _searchResults = [];
      _searchController.clear();
      _searchError = null;
      _isLoadingAddress = true;
    });

    try {
      _mapController.move(point, 16);
    } catch (_) {}

    try {
      final String? address = await GeocodingService.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (!mounted) return;

      final String resolvedAddress = address?.trim().isNotEmpty == true
          ? address!.trim()
          : 'Lokasi dipilih';

      _syncSelection(
        address: resolvedAddress,
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } catch (_) {
      if (!mounted) return;

      _syncSelection(
        address: 'Lokasi dipilih',
        latitude: point.latitude,
        longitude: point.longitude,
      );

      _showSnack(
        'Alamat detail tidak ditemukan, tetapi lokasi tetap tersimpan.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onSearchResultSelected(Map<String, dynamic> result) {
    final double? latitude = result['lat'] as double?;

    final double? longitude = result['lon'] as double?;

    final String? displayName = result['display_name'] as String?;

    if (latitude == null || longitude == null) {
      return;
    }

    final LatLng point = LatLng(latitude, longitude);

    final String resolvedAddress = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : 'Lokasi terpilih';

    _syncSelection(
      address: resolvedAddress,
      latitude: latitude,
      longitude: longitude,
    );

    setState(() {
      _selectedPoint = point;
      _searchController.clear();
      _searchResults = [];
      _searchError = null;
    });

    _searchFocusNode.unfocus();

    try {
      _mapController.move(point, 16);
    } catch (_) {}
  }

  Future<void> _useCurrentLocation() async {
    if (_isLoadingAddress) return;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationBanner = LocationBannerState.serviceOff);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationBanner = LocationBannerState.denied);
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationBanner = LocationBannerState.deniedForever);
        }
        return;
      }

      setState(() {
        _isLoadingAddress = true;
      });

      // timeLimit supaya tidak menggantung selamanya kalau GPS tak kunjung
      // mendapatkan fix (akan melempar TimeoutException → finally reset loading).
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      final LatLng point = LatLng(position.latitude, position.longitude);

      // Simpan koordinat terlebih dahulu.
      // Jangan menunggu reverse geocoding.
      setState(() {
        _selectedPoint = point;
        _searchResults = [];
        _searchError = null;
        _locationBanner = null;
        _searchController.clear();

        if (_selectedType == _LocationType.pickup) {
          _pickupAddress = 'Lokasi saat ini';
          _pickupLat = point.latitude;
          _pickupLng = point.longitude;
        } else {
          _destinationAddress = 'Lokasi saat ini';
          _destinationLat = point.latitude;
          _destinationLng = point.longitude;
        }
      });

      try {
        _mapController.move(point, 16);
      } catch (_) {}

      _searchFocusNode.unfocus();

      // Tutup loading segera setelah koordinat ditemukan.
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }

      // Nama alamat dicari setelah koordinat tersimpan.
      // Kegagalan geocoding tidak membatalkan pilihan lokasi.
      try {
        final String? address = await GeocodingService.reverseGeocode(
          point.latitude,
          point.longitude,
        ).timeout(const Duration(seconds: 8));

        if (!mounted) return;

        final String resolvedAddress = address?.trim().isNotEmpty == true
            ? address!.trim()
            : 'Lokasi saat ini';

        _syncSelection(
          address: resolvedAddress,
          latitude: point.latitude,
          longitude: point.longitude,
        );
      } catch (_) {
        // Koordinat sudah tersimpan.
        // Tidak perlu mengaktifkan loading kembali.
        if (!mounted) return;

        _syncSelection(
          address: 'Lokasi saat ini',
          latitude: point.latitude,
          longitude: point.longitude,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showSnack('Gagal mendapatkan lokasi. Pastikan GPS aktif lalu coba lagi.');
    } finally {
      if (mounted && _isLoadingAddress) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  bool get _canConfirm =>
      _pickupLat != null &&
      _pickupLng != null &&
      _destinationLat != null &&
      _destinationLng != null;

  void _confirm() {
    if (!_canConfirm) {
      _showSnack('Lengkapi lokasi pickup dan tujuan terlebih dahulu.');
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
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint ?? _defaultCenter,
              initialZoom: _selectedPoint != null ? 15 : 13,
              onTap: (_, point) {
                _onMapTap(point);
              },
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
                      width: 48,
                      height: 48,
                      child: const Icon(
                        CupertinoIcons.location_north_fill,
                        color: _pickupBlue,
                        size: 39,
                      ),
                    ),
                  if (_destinationLat != null && _destinationLng != null)
                    Marker(
                      point: LatLng(_destinationLat!, _destinationLng!),
                      width: 48,
                      height: 48,
                      child: const Icon(
                        CupertinoIcons.location_solid,
                        color: _destinationRed,
                        size: 39,
                      ),
                    ),
                ],
              ),
            ],
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 10),
                _buildSearchPanel(),
                if (_locationBanner != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: LocationStatusBanner(
                      state: _locationBanner!,
                      onRetry: _useCurrentLocation,
                    ),
                  ),
                const Spacer(),
                _buildBottomPanel(),
              ],
            ),
          ),

          if (_isLoadingAddress)
            Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: CircularProgressIndicator(color: _primaryBlue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            elevation: 5,
            borderRadius: BorderRadius.circular(14),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textDark,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.13),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Pilih Lokasi',
                style: GoogleFonts.inter(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    final bool showResults = _searchController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderBlue),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: _LocationTypeButton(
                      label: 'Pickup',
                      icon: Icons.location_on_outlined,
                      active: _selectedType == _LocationType.pickup,
                      color: _pickupBlue,
                      onTap: () {
                        _setLocationType(_LocationType.pickup);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LocationTypeButton(
                      label: 'Tujuan',
                      icon: Icons.location_on_rounded,
                      active: _selectedType == _LocationType.destination,
                      color: _destinationRed,
                      onTap: () {
                        _setLocationType(_LocationType.destination);
                      },
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
                style: GoogleFonts.inter(color: _textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _selectedType == _LocationType.pickup
                      ? 'Cari lokasi pickup'
                      : 'Cari lokasi tujuan',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFFA2ABBA),
                    fontSize: 13.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _titleBlue,
                    size: 23,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? IconButton(
                          onPressed: _useCurrentLocation,
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: _primaryBlue,
                            size: 21,
                          ),
                        )
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();

                            _onSearchChanged('');

                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF4F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: showResults
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: _buildSearchResults(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryBlue,
            ),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          _searchError ?? 'Tidak ada hasil pencarian',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: _textGrey, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) {
        return const Divider(height: 1, color: Color(0xFFE6EAF0));
      },
      itemBuilder: (context, index) {
        final result = _searchResults[index];

        final String title = result['display_name'] as String? ?? 'Alamat';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 3,
          ),
          leading: Icon(
            _selectedType == _LocationType.pickup
                ? Icons.location_on_outlined
                : Icons.location_on_rounded,
            color: _selectedType == _LocationType.pickup
                ? _pickupBlue
                : _destinationRed,
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _textDark,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          trailing: const Icon(
            Icons.north_east_rounded,
            size: 18,
            color: _textGrey,
          ),
          onTap: () {
            _onSearchResultSelected(result);
          },
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderBlue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lokasi yang dipilih',
                  style: GoogleFonts.inter(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  'Lokasi Saya',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _LocationPreviewCard(
            title: 'Pickup',
            address: _pickupAddress,
            icon: Icons.location_on_outlined,
            color: _pickupBlue,
            selected: _selectedType == _LocationType.pickup,
            onTap: () {
              _setLocationType(_LocationType.pickup);
            },
          ),

          const SizedBox(height: 10),

          _LocationPreviewCard(
            title: 'Tujuan',
            address: _destinationAddress,
            icon: Icons.location_on_rounded,
            color: _destinationRed,
            selected: _selectedType == _LocationType.destination,
            onTap: () {
              _setLocationType(_LocationType.destination);
            },
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canConfirm ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.40),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Gunakan Lokasi Ini',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _LocationTypeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.10)
                : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? color : const Color(0xFFDDE3EC),
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? color : const Color(0xFF8F99A8),
                size: 21,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: active ? color : const Color(0xFF778291),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPreviewCard extends StatelessWidget {
  final String title;
  final String? address;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _LocationPreviewCard({
    required this.title,
    required this.address,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAddress = address?.trim().isNotEmpty == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color : const Color(0xFFDCE4EF),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasAddress ? address! : 'Belum dipilih',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6F7784),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? color : const Color(0xFFB1BAC7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
