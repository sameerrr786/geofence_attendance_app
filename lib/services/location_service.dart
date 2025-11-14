import 'package:flutter/foundation.dart'; // Import for kDebugMode & defaultTargetPlatform
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';

class LocationService {
  final Geodesy geodesy = Geodesy();

  // ✅ --- EDITED: Set buffer to a strict 3 meters as requested ---
  // This is a 3-meter (10ft) vertical buffer, perfect for a single floor.
  static const double MAX_ALTITUDE_DIFFERENCE = 1.0;
  // Define a tighter default radius (e.g., 10m) to reduce horizontal error
  static const double DEFAULT_STRICT_RADIUS = 10.0;

  /// Checks if the user has location permission and requests if necessary.
  /// Returns true if permission was newly requested, false otherwise.
  Future<bool> _handleLocationPermission() async {
    bool permissionJustRequested = false;
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        print('[LocationService] Permission denied, requesting...');
      }
      permission = await Geolocator.requestPermission();
      permissionJustRequested = true;
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('[LocationService] Permission denied by user.');
        }
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('[LocationService] Permission permanently denied.');
      }
      throw Exception(
        'Location permissions are permanently denied. Please enable them in settings.',
      );
    }

    if (kDebugMode) {
      print('[LocationService] Location permission granted.');
    }
    return permissionJustRequested; // <-- 3. Return the status
  }

  /// Checks if the user is within the geofence, both horizontally and vertically.
  Future<bool> isWithinGeofence({
    required double classLat,
    required double classLng,
    required double classAltitude, // NEW: Expected altitude of the classroom
    double radius = DEFAULT_STRICT_RADIUS, // NEW: Uses a stricter default
  }) async {
    try {
      // 1. Check and request location permissions
      final bool permissionWasRequested = await _handleLocationPermission();

      // If we just requested permission, wait a moment for the OS to apply it
      if (permissionWasRequested &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 2. Get the user's current location, including altitude
      if (kDebugMode) {
        print("[LocationService] Getting current location (with altitude)...");
      }
      final Position userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.bestForNavigation, // Use best accuracy
      );

      // ✅ --- NEW: PRINT THE USER'S CURRENT ALTITUDE ---
      if (kDebugMode) {
        print(
          "--- 📍 YOUR CURRENT ALTITUDE: ${userPosition.altitude.toStringAsFixed(2)}m ---",
        );
      }
      // --- END OF NEW CODE ---

      final double currentAltitude = userPosition.altitude;
      final double altitudeDifference = (currentAltitude - classAltitude).abs();

      // --- Vertical Check ---
      if (altitudeDifference > MAX_ALTITUDE_DIFFERENCE) {
        if (kDebugMode) {
          print(
            "❌ [Vertical Check] FAILED. Difference: ${altitudeDifference.toStringAsFixed(2)}m (Max allowed: ${MAX_ALTITUDE_DIFFERENCE}m)",
          );
        }
        throw Exception(
          'You are on the wrong floor. Altitude difference is too large.',
        );
      }

      // --- Horizontal Check ---
      final LatLng userLocation = LatLng(
        userPosition.latitude,
        userPosition.longitude,
      );
      final LatLng classLocation = LatLng(classLat, classLng);

      // 3. Calculate the horizontal distance
      final num distance = geodesy.distanceBetweenTwoGeoPoints(
        userLocation,
        classLocation,
      );

      if (kDebugMode) {
        print(
          "📏 [Horizontal Check] Distance: ${distance.toStringAsFixed(2)} meters",
        );
      }

      // 4. Compare distance to the radius
      final bool isInside = distance <= radius;

      if (kDebugMode) {
        print(
          "[LocationService] User is ${isInside ? 'INSIDE' : 'OUTSIDE'} the geofence (Radius: ${radius}m).",
        );
      }

      if (!isInside) {
        throw Exception('You are outside the required classroom area.');
      }

      return true; // Both vertical and horizontal checks passed
    } catch (e) {
      if (kDebugMode) {
        print("❌ [LocationService] Error checking location: $e");
      }
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }
}
