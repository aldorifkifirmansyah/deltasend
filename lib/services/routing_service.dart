import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> routePoints;
  final double distanceMeters;
  final double durationSeconds;

  const RouteInfo({
    required this.routePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;

  int get durationMinutes {
    return (durationSeconds / 60).ceil();
  }
}

class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  static const Duration _requestTimeout = Duration(seconds: 20);

  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  // =========================================================
  // ROUTE POINTS
  // Tetap dipakai oleh MapViewModel.
  // =========================================================

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final RouteInfo routeInfo = await getRouteInfo(start, end);

    return routeInfo.routePoints;
  }

  // =========================================================
  // ROUTE INFO
  // Mengembalikan:
  // - daftar titik rute
  // - jarak dalam meter
  // - durasi dalam detik
  // =========================================================

  Future<RouteInfo> getRouteInfo(LatLng start, LatLng end) async {
    _validateCoordinate(point: start, label: 'lokasi awal');

    _validateCoordinate(point: end, label: 'lokasi tujuan');

    final Uri uri =
        Uri.parse(
          '$_baseUrl/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}',
        ).replace(
          queryParameters: const {
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'false',
            'alternatives': 'false',
          },
        );

    try {
      final http.Response response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw RoutingException(
          'Server routing gagal merespons. '
          'Status: ${response.statusCode}.',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const RoutingException('Format respons routing tidak valid.');
      }

      final String responseCode = decoded['code']?.toString() ?? '';

      if (responseCode != 'Ok') {
        final String message =
            decoded['message']?.toString() ?? 'Rute tidak ditemukan.';

        throw RoutingException(message);
      }

      final dynamic routesValue = decoded['routes'];

      if (routesValue is! List || routesValue.isEmpty) {
        throw const RoutingException('Rute tidak ditemukan antara dua lokasi.');
      }

      final dynamic firstRoute = routesValue.first;

      if (firstRoute is! Map<String, dynamic>) {
        throw const RoutingException('Data rute tidak valid.');
      }

      final dynamic geometry = firstRoute['geometry'];

      if (geometry is! Map<String, dynamic>) {
        throw const RoutingException('Geometri rute tidak tersedia.');
      }

      final dynamic coordinatesValue = geometry['coordinates'];

      if (coordinatesValue is! List || coordinatesValue.isEmpty) {
        throw const RoutingException('Titik koordinat rute tidak tersedia.');
      }

      final List<LatLng> routePoints = <LatLng>[];

      for (final dynamic coordinate in coordinatesValue) {
        if (coordinate is! List || coordinate.length < 2) {
          continue;
        }

        final double? longitude = _toDouble(coordinate[0]);

        final double? latitude = _toDouble(coordinate[1]);

        if (latitude == null || longitude == null) {
          continue;
        }

        routePoints.add(LatLng(latitude, longitude));
      }

      if (routePoints.length < 2) {
        throw const RoutingException('Titik rute yang diterima tidak cukup.');
      }

      final double distanceMeters = _toDouble(firstRoute['distance']) ?? 0;

      final double durationSeconds = _toDouble(firstRoute['duration']) ?? 0;

      return RouteInfo(
        routePoints: routePoints,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } on TimeoutException {
      throw const RoutingException(
        'Permintaan rute terlalu lama. '
        'Periksa koneksi internet lalu coba kembali.',
      );
    } on FormatException {
      throw const RoutingException(
        'Respons dari server routing tidak dapat dibaca.',
      );
    } on RoutingException {
      rethrow;
    } on http.ClientException catch (error) {
      throw RoutingException(
        'Tidak dapat terhubung ke server routing: '
        '${error.message}',
      );
    } catch (error) {
      throw RoutingException('Gagal mengambil rute: $error');
    }
  }

  // =========================================================
  // ROUTE INFO AMAN
  // Tidak melempar error. Cocok untuk preview kecil.
  // =========================================================

  Future<RouteInfo?> getRouteInfoOrNull(LatLng start, LatLng end) async {
    try {
      return await getRouteInfo(start, end);
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // STRAIGHT-LINE FALLBACK
  // Dipakai jika server OSRM tidak dapat dijangkau.
  // =========================================================

  RouteInfo createFallbackRoute(LatLng start, LatLng end) {
    final Distance distanceCalculator = const Distance();

    final double distanceMeters = distanceCalculator.as(
      LengthUnit.Meter,
      start,
      end,
    );

    // Perkiraan kecepatan kendaraan rata-rata 30 km/jam.
    const double estimatedSpeedMetersPerSecond = 30 * 1000 / 3600;

    final double durationSeconds = estimatedSpeedMetersPerSecond > 0
        ? distanceMeters / estimatedSpeedMetersPerSecond
        : 0;

    return RouteInfo(
      routePoints: [start, end],
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  // =========================================================
  // ROUTE DENGAN FALLBACK
  // Jika OSRM gagal, aplikasi tetap menampilkan garis lurus.
  // =========================================================

  Future<RouteInfo> getRouteInfoWithFallback(LatLng start, LatLng end) async {
    try {
      return await getRouteInfo(start, end);
    } catch (_) {
      return createFallbackRoute(start, end);
    }
  }

  void _validateCoordinate({required LatLng point, required String label}) {
    final bool latitudeValid = point.latitude >= -90 && point.latitude <= 90;

    final bool longitudeValid =
        point.longitude >= -180 && point.longitude <= 180;

    if (!latitudeValid || !longitudeValid) {
      throw RoutingException('Koordinat $label tidak valid.');
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  void dispose() {
    _client.close();
  }
}

class RoutingException implements Exception {
  final String message;

  const RoutingException(this.message);

  @override
  String toString() {
    return message;
  }
}
