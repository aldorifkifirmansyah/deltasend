import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// farell: hasil routing lengkap (dipakai customer map picker buat hitung jarak)
class RouteInfo {
  final List<LatLng> routePoints;
  final double distanceMeters;
  final double durationSeconds;

  RouteInfo({
    required this.routePoints,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RoutingService {
  // method lama: tetap dipakai MapViewModel, jangan diubah
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List coordinates = data['routes'][0]['geometry']['coordinates'];

      return coordinates.map((point) => LatLng(point[1], point[0])).toList();
    } else {
      throw Exception('Gagal ambil rute bro!');
    }
  }

  // method baru: kembalikan route + jarak (meter) + durasi (detik)
  Future<RouteInfo> getRouteInfo(LatLng start, LatLng end) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Gagal ambil rute (status ${response.statusCode})');
    }

    final data = json.decode(response.body);
    final List? routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('Rute tidak ditemukan antara dua titik tersebut');
    }

    final route = routes[0];
    final List coordinates = route['geometry']['coordinates'];

    return RouteInfo(
      routePoints:
          coordinates.map((point) => LatLng(point[1], point[0])).toList(),
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0.0,
    );
  }
}