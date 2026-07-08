import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  /// Default center fallback coordinates (Chennai, India)
  static const double defaultLat = 13.0827;
  static const double defaultLng = 80.2707;

  /// Fetches the user's current GPS location.
  /// Falls back to default Hyderabad coordinates if permission is denied or service unavailable.
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (e) {
        debugPrint('getCurrentPosition failed, trying getLastKnownPosition: $e');
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      return null;
    }
  }

  /// Calculates distance in km between user position and hospital coordinates.
  static double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000.0;
  }
}
