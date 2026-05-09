import 'package:http/http.dart' as http;
import 'dart:convert';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  static Future<String> getAddress(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/reverse?lat=$lat&lon=$lng&format=json&addressdetails=0&zoom=18',
        ),
        headers: {'User-Agent': 'GigsCourt/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] as String? ?? 'Unknown location';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }
}
