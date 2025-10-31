import 'package:flutter/foundation.dart'; // Import for kDebugMode & defaultTargetPlatform
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';

class LocationService {
  final Geodesy geodesy = Geodesy();

  /// Checks if the user has location permission and requests if necessary.
  /// Returns true if permission was newly requested, false otherwise.
  Future<bool> _handleLocationPermission() async {
    bool permissionJustRequested = false; // <-- 1. Track if we requested
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        print('[LocationService] Permission denied, requesting...');
      }
      permission = await Geolocator.requestPermission();
      permissionJustRequested = true; // <-- 2. Mark that we requested
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
    return permissionJustRequested; // <-- 3. Return the status
  }

  /// Checks if the user is within the geofence.
  Future<bool> isWithinGeofence({
    required double classLat,
    required double classLng,
    required double radius,
  }) async {
    try {
      // 1. Check and request location permissions
      final bool permissionWasRequested = await _handleLocationPermission();

      // --- 4. NEW FIX FOR MACOS/IOS RACE CONDITION ---
      // If we just requested permission, wait a moment for the OS to apply it
      // before we try to get the current position.
      if (permissionWasRequested &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      // --- END OF FIX ---

      // 2. Get the user's current location
      if (kDebugMode) {
        print("[LocationService] Getting current location...");
      }
      final Position userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // --- (Logging and logic unchanged) ---
      if (kDebugMode) {
        print(
          "📍 [LocationService] Your Location: Lat: ${userPosition.latitude}, Lng: ${userPosition.longitude} (Accuracy: ${userPosition.accuracy}m)",
        );
        print(
          "🎯 [LocationService] Classroom Location: Lat: $classLat, Lng: $classLng",
        );
        print("⭕ [LocationService] Required Radius: ${radius}m");
      }

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
