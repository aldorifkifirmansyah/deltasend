import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';

// farell: hasil yang dikembalikan ke CustomerCreateOrderScreen
class MapPickerResult {
  final LatLng pickup;
  final LatLng destination;
  final double distanceMeters;

  MapPickerResult({
    required this.pickup,
    required this.destination,
    required this.distanceMeters,
  });
}

enum _PickMode { pickup, destination }

class CustomerMapPickerScreen extends StatefulWidget {
  // titik awal opsional (kalau user sudah pernah pilih sebelumnya)
  final LatLng? initialPickup;
  final LatLng? initialDestination;

  const CustomerMapPickerScreen({
    super.key,
    this.initialPickup,
    this.initialDestination,
  });

  @override
  State<CustomerMapPickerScreen> createState() =>
      _CustomerMapPickerScreenState();
}

class _CustomerMapPickerScreenState extends State<CustomerMapPickerScreen> {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();

  // default center: area Jember (sesuai default MapDriverScreen)
  static const LatLng _defaultCenter = LatLng(-8.1689, 113.7022);

  _PickMode _mode = _PickMode.pickup;
  LatLng? _pickup;
  LatLng? _destination;
  LatLng? _currentLocation;

  List<LatLng> _routePoints = [];
  double? _distanceMeters;

  bool _isCalculating = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _pickup = widget.initialPickup;
    _destination = widget.initialDestination;
    if (_pickup != null && _destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateRoute();
        _fitToBounds();
      });
    }
    _initCurrentLocation();
  }

  // coba ambil lokasi user; kalau gagal/ditolak, diam dan tetap pakai default
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
      setState(() => _currentLocation = loc);

      // center ke lokasi user hanya jika belum ada titik yang dipilih
      if (_pickup == null && _destination == null) {
        try {
          _mapController.move(loc, 15.0);
        } catch (_) {
          // map belum siap, abaikan
        }
      }
    } catch (_) {
      // fallback diam ke default Jember
    }
  }

  void _goToMyLocation() {
    if (_currentLocation == null) return;
    _mapController.move(_currentLocation!, 15.0);
  }

  // auto-fit map ke pickup & tujuan biar dua titik kelihatan jelas
  void _fitToBounds() {
    if (_pickup == null || _destination == null) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [_pickup!, _destination!],
          padding: const EdgeInsets.only(
            top: 140,
            left: 50,
            right: 50,
            bottom: 180,
          ),
          maxZoom: 16.0,
        ),
      );
    } catch (_) {
      // map belum siap, abaikan
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      if (_mode == _PickMode.pickup) {
        _pickup = point;
      } else {
        _destination = point;
      }
      // reset hasil lama karena titik berubah
      _routePoints = [];
      _distanceMeters = null;
      _errorText = null;
    });

    if (_pickup != null && _destination != null) {
      _recalculateRoute();
    }
  }

  Future<void> _recalculateRoute() async {
    if (_pickup == null || _destination == null) return;

    setState(() {
      _isCalculating = true;
      _errorText = null;
    });

    try {
      final info = await _routingService.getRouteInfo(_pickup!, _destination!);
      if (!mounted) return;
      setState(() {
        _routePoints = info.routePoints;
        _distanceMeters = info.distanceMeters;
      });
      _fitToBounds();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routePoints = [];
        _distanceMeters = null;
        _errorText = 'Gagal menghitung rute: $e';
      });
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  void _confirm() {
    if (_pickup == null || _destination == null || _distanceMeters == null) {
      return;
    }
    Navigator.of(context).pop(
      MapPickerResult(
        pickup: _pickup!,
        destination: _destination!,
        distanceMeters: _distanceMeters!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _pickup != null &&
        _destination != null &&
        _distanceMeters != null &&
        !_isCalculating;

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
              initialCenter: _pickup ?? _defaultCenter,
              initialZoom: 14.0,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.deltasend.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_pickup != null)
                    Marker(
                      point: _pickup!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.green,
                        size: 35,
                      ),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 35,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // panel atas: pilih mode + instruksi
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeButton(
                            label: 'Set Pickup',
                            icon: Icons.my_location,
                            active: _mode == _PickMode.pickup,
                            color: Colors.green,
                            onTap: () =>
                                setState(() => _mode = _PickMode.pickup),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildModeButton(
                            label: 'Set Tujuan',
                            icon: Icons.flag,
                            active: _mode == _PickMode.destination,
                            color: Colors.red,
                            onTap: () =>
                                setState(() => _mode = _PickMode.destination),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih mode Set Pickup atau Set Tujuan, lalu tap pada peta',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _mode == _PickMode.pickup
                          ? 'Mode aktif: menentukan titik PICKUP'
                          : 'Mode aktif: menentukan titik TUJUAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _mode == _PickMode.pickup
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // tombol "Lokasi Saya": hanya muncul jika lokasi user tersedia
          if (_currentLocation != null)
            Positioned(
              top: 130,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'picker_my_location',
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                mini: true,
                tooltip: 'Lokasi Saya',
                onPressed: _goToMyLocation,
                child: const Icon(Icons.my_location),
              ),
            ),

          // panel bawah: info jarak + tombol konfirmasi
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
                  children: [
                    if (_isCalculating)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Menghitung rute...'),
                          ],
                        ),
                      )
                    else if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_distanceMeters != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Jarak rute: ${(_distanceMeters! / 1000).toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Pilih titik pickup & tujuan',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
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

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: active ? Colors.white : color, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? color : Colors.transparent,
        foregroundColor: active ? Colors.white : color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
