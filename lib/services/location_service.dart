import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<String> getCurrentLocation() async {
    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        return 'Location permission denied';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String location =
          await _getAddressFromLatLng(position.latitude, position.longitude);

      if (location.isEmpty || location == 'Location unavailable') {
        location =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return location;
    } catch (e) {
      print('Error getting location: $e');
      return 'Location unavailable';
    }
  }

  /// Get district and province from coordinates
  Future<Map<String, String?>> getDistrictAndProvince(
      double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'VesakGO/2.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};

        // Sri Lanka specific address fields
        String? district = address['state_district'] ??
            address['county'] ??
            address['city_district'];

        String? province =
            address['state'] ?? address['province'] ?? address['region'];

        // Clean up district name (remove "District" suffix if present)
        if (district != null) {
          district = district.replaceAll(' District', '');
        }

        // Map to Sri Lankan province names
        province = _normalizeProvince(province);

        // Fallback: try to infer from city if district missing
        if (district == null && address['city'] != null) {
          district = _inferDistrictFromCity(address['city']);
        }

        return {'district': district, 'province': province};
      }
      return {'district': null, 'province': null};
    } catch (e) {
      print('Reverse geocoding error: $e');
      return {'district': null, 'province': null};
    }
  }

  String? _normalizeProvince(String? province) {
    if (province == null) return null;

    final provinceMap = {
      'Western': 'Western Province',
      'Central': 'Central Province',
      'Southern': 'Southern Province',
      'Northern': 'Northern Province',
      'Eastern': 'Eastern Province',
      'North Western': 'North Western Province',
      'North Central': 'North Central Province',
      'Uva': 'Uva Province',
      'Sabaragamuwa': 'Sabaragamuwa Province',
    };

    for (var entry in provinceMap.entries) {
      if (province.contains(entry.key)) {
        return entry.value;
      }
    }
    return province;
  }

  String? _inferDistrictFromCity(String city) {
    final cityToDistrict = {
      'Colombo': 'Colombo',
      'Kandy': 'Kandy',
      'Galle': 'Galle',
      'Jaffna': 'Jaffna',
      'Negombo': 'Gampaha',
      'Gampaha': 'Gampaha',
      'Kurunegala': 'Kurunegala',
      'Matara': 'Matara',
      'Ratnapura': 'Ratnapura',
      'Badulla': 'Badulla',
      'Batticaloa': 'Batticaloa',
      'Trincomalee': 'Trincomalee',
      'Anuradhapura': 'Anuradhapura',
      'Polonnaruwa': 'Polonnaruwa',
      'Nuwara Eliya': 'Nuwara Eliya',
      'Matale': 'Matale',
      'Kalutara': 'Kalutara',
      'Kalmunai': 'Ampara',
      'Vavuniya': 'Vavuniya',
      'Mannar': 'Mannar',
      'Kilinochchi': 'Kilinochchi',
      'Mullaitivu': 'Mullaitivu',
      'Puttalam': 'Puttalam',
      'Chilaw': 'Puttalam',
      'Kegalle': 'Kegalle',
      'Monaragala': 'Monaragala',
      'Hambantota': 'Hambantota',
    };
    return cityToDistrict[city];
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'VesakGO/2.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['address'] != null) {
          final address = data['address'];

          // Build a readable address
          String location = '';

          // Road name
          if (address['road'] != null && address['road'].isNotEmpty) {
            location = address['road'];
          } else if (address['suburb'] != null &&
              address['suburb'].isNotEmpty) {
            location = address['suburb'];
          } else if (address['village'] != null &&
              address['village'].isNotEmpty) {
            location = address['village'];
          } else if (address['town'] != null && address['town'].isNotEmpty) {
            location = address['town'];
          } else if (address['city'] != null && address['city'].isNotEmpty) {
            location = address['city'];
          }

          // Add district
          final district = address['state_district'] ?? address['county'];
          if (district != null && district.isNotEmpty && location.isNotEmpty) {
            location += ', $district';
          } else if (district != null && district.isNotEmpty) {
            location = district;
          }

          // Add country
          if (address['country'] != null && address['country'].isNotEmpty) {
            if (location.isNotEmpty) {
              location += ', ${address['country']}';
            } else {
              location = address['country'];
            }
          }

          return location.isEmpty ? 'Location unavailable' : location;
        }
      }

      return 'Location unavailable';
    } catch (e) {
      print('Error getting address: $e');
      return 'Location unavailable';
    }
  }

  // Get list of all Sri Lankan districts for filtering
  static const List<String> sriLankanDistricts = [
    'Colombo',
    'Gampaha',
    'Kalutara',
    'Kandy',
    'Matale',
    'Nuwara Eliya',
    'Galle',
    'Matara',
    'Hambantota',
    'Jaffna',
    'Kilinochchi',
    'Mannar',
    'Mullaitivu',
    'Vavuniya',
    'Batticaloa',
    'Ampara',
    'Trincomalee',
    'Kurunegala',
    'Puttalam',
    'Anuradhapura',
    'Polonnaruwa',
    'Badulla',
    'Monaragala',
    'Ratnapura',
    'Kegalle'
  ];

  // Get list of provinces
  static const List<String> sriLankanProvinces = [
    'Western Province',
    'Central Province',
    'Southern Province',
    'Northern Province',
    'Eastern Province',
    'North Western Province',
    'North Central Province',
    'Uva Province',
    'Sabaragamuwa Province'
  ];
}
