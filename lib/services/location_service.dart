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

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['address'] != null) {
          final address = data['address'];

          String location = '';

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
}
