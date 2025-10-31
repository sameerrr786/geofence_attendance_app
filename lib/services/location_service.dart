// lib/services/location_service.dart
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';

class LocationService {
  final Geodesy geodesy = Geodesy();

  /// Checks if the user has location permission and requests if necessary.
  /// Returns true if permission is granted, throws an exception otherwise.
  Future<bool> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        print('[LocationService] Permission denied, requesting...');
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('[LocationService] Permission denied by user.');
        }
        // User denied permissions
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('[LocationService] Permission permanently denied.');
      }
      // User permanently denied permissions
      throw Exception(
        'Location permissions are permanently denied. Please enable them in settings.',
      );
    }

    if (kDebugMode) {
      print('[LocationService] Location permission granted.');
    }
    return true; // Permission granted
  }

  /// Checks if the user is within the geofence.
  Future<bool> isWithinGeofence({
    required double classLat,
    required double classLng,
    required double radius,
  }) async {
    try {
      // 1. Check and request location permissions
      await _handleLocationPermission();

      // 2. Get the user's current location
      if (kDebugMode) {
        print("[LocationService] Getting current location...");
      }
      final Position userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        // Optional: Add a timeout
        // timeLimit: const Duration(seconds: 10),
      );

      // --- Added detailed logging ---
      if (kDebugMode) {
        print(
          "📍 [LocationService] Your Location: Lat: ${userPosition.latitude}, Lng: ${userPosition.longitude} (Accuracy: ${userPosition.accuracy}m)",
        );
        print(
          "🎯 [LocationService] Classroom Location: Lat: $classLat, Lng: $classLng",
        );
        print("⭕ [LocationService] Required Radius: ${radius}m");
      }
      // --- End of added logging ---

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

      if (kDebugMode) {
        print(
          "📏 [LocationService] Calculated Distance: ${distance.toStringAsFixed(2)} meters",
        );
      }

      // 4. Compare distance to the radius
      final bool isInside = distance <= radius;
      if (kDebugMode) {
        print(
          "[LocationService] User is ${isInside ? 'INSIDE' : 'OUTSIDE'} the geofence.",
        );
      }
      return isInside;
    } catch (e) {
      if (kDebugMode) {
        print("❌ [LocationService] Error checking location: $e");
      }
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }
}
