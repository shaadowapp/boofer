import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<String?> getCityStateFromIP() async {
    try {
      // Using ip-api.com (free for non-commercial, no API key needed)
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final city = data['city'] ?? '';
          final region = data['regionName'] ?? '';
          final country = data['country'] ?? '';

          if (city.isNotEmpty && region.isNotEmpty) {
            return '$city, $region';
          } else if (city.isNotEmpty) {
            return city;
          } else {
            return country;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting location from IP: $e');
    }
    return null;
  }
}
