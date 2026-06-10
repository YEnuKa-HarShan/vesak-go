import 'package:geolocator/geolocator.dart';

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

  Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<String> getFormattedLocationString() async {
    try {
      final position = await getCurrentPosition();
      if (position != null) {
        return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
      return 'Location unavailable';
    } catch (e) {
      print('Error getting formatted location: $e');
      return 'Location unavailable';
    }
  }

  // Helper to get just coordinates as map
  Future<Map<String, double>?> getCoordinates() async {
    final position = await getCurrentPosition();
    if (position != null) {
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    }
    return null;
  }

  // Get both coordinates and formatted string
  Future<Map<String, dynamic>?> getLocationData() async {
    final position = await getCurrentPosition();
    if (position != null) {
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'formatted':
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      };
    }
    return null;
  }

  // Sri Lankan districts list for reference
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
