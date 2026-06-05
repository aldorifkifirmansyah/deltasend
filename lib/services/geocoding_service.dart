import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=id',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'DeltaSend_PBM_Project_App',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          return {
            'display_name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
          };
        }).toList();
      }
    } catch (e) {
      // ignore: avoid_print
      print("Geocoding Error: $e");
    }
    return [];
  }
  
  static Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=id'
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'DeltaSend_PBM_Project_App',
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      // ignore: avoid_print
      print("Reverse Geocoding Error: $e");
    }
    return null;
  }
}
