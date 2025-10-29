// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';

class LocationService {
  final Geodesy geodesy = Geodesy();

  /// Checks if the user is within the geofence.
  Future<bool> isWithinGeofence({
    required double classLat,
    required double classLng,
    required double radius,
  }) async {
    try {
      // 1. Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // User denied permissions
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // User permanently denied permissions
        throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }

      // 2. Get the user's current location
      print("Getting current location...");
      final Position userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final LatLng userLocation = LatLng(
        userPosition.latitude,
        userPosition.longitude,
      );
      final LatLng classLocation = LatLng(classLat, classLng);

      // 3. Calculate the distance
      final num distance = geodesy.distanceBetweenTwoGeoPoints(
        userLocation,
        classLocation,
      );

      print("User is $distance meters away from the class.");

      // 4. Compare distance to the radius
      return distance <= radius;
    } catch (e) {
      print("Error checking location: $e");
      rethrow; // Re-throw the error so the UI can catch it
    }
  }
}
