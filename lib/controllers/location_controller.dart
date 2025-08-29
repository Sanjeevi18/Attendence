import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'auth_controller.dart';

class LocationController extends GetxController {
  var isLoading = false.obs;
  var hasPermission = false.obs;
  var hasLocationService = false.obs;
  var currentLocation = Rxn<Position>();
  var currentAddress = 'Getting location...'.obs;
  var errorMessage = ''.obs;
  var isTracking = false.obs;
  var locationAccuracy = 'GPS'.obs;

  StreamSubscription<Position>? _positionSubscription;
  final AuthController _authController = Get.find<AuthController>();

  // Track if location has been loaded to avoid repeated loading
  bool _hasLoadedLocation = false;
  DateTime? _lastLocationUpdate;

  @override
  void onInit() {
    super.onInit();
    _initializeLocation();
  }

  @override
  void onClose() {
    stopLocationTracking();
    super.onClose();
  }

  Future<void> _initializeLocation() async {
    try {
      // Only initialize if not already loaded
      if (_hasLoadedLocation &&
          _lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inMinutes < 5) {
        print('Location already loaded recently, skipping initialization');
        return;
      }

      // Always check permissions first
      await checkLocationPermission();
      if (hasPermission.value) {
        await getCurrentLocation();
        _hasLoadedLocation = true;
        _lastLocationUpdate = DateTime.now();
      } else {
        currentAddress.value = 'Location permission required';
        errorMessage.value = 'Location permission required';
      }
    } catch (e) {
      print('Error initializing location: $e');
      errorMessage.value = 'Error initializing location: $e';
      currentAddress.value = 'Location initialization failed';
    }
  }

  Future<void> startLocationTracking() async {
    if (isTracking.value) return;

    try {
      if (!hasPermission.value) {
        await checkLocationPermission();
        if (!hasPermission.value) {
          Get.snackbar(
            'Permission Required',
            'Location permission is required for attendance tracking',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }
      }

      // High accuracy settings similar to React Native version
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best, // Changed to best for highest accuracy
        distanceFilter: 5, // Update every 5 meters for higher precision
        timeLimit: Duration(
          seconds: 15,
        ), // Increased timeout for better accuracy
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              print(
                'Location update received: ${position.latitude}, ${position.longitude}',
              );
              currentLocation.value = position;

              // Always display GPS for accuracy
              locationAccuracy.value = 'GPS';

              // Update address in background to avoid blocking
              _updateAddressAsync(position.latitude, position.longitude);

              // Update Firestore location
              await _updateFirestoreLocation(position);
            },
            onError: (error) {
              print('Location tracking error: $error');
              errorMessage.value = 'Location tracking error: $error';
              Get.snackbar(
                'Location Error',
                'Error tracking location: $error',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
            },
          );

      isTracking.value = true;
      print('Location tracking started successfully');
    } catch (e) {
      print('Error starting location tracking: $e');
      errorMessage.value = 'Error starting location tracking: $e';
      Get.snackbar(
        'Error',
        'Failed to start location tracking',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    isTracking.value = false;
    print('Location tracking stopped');
  }

  Future<void> _updateFirestoreLocation(Position position) async {
    try {
      final user = _authController.currentUser.value;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(user.id)
          .update({
            'currentLocation': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
            },
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error updating location in Firestore: $e');
    }
  }

  // Background address update to avoid blocking UI
  void _updateAddressAsync(double lat, double lon) {
    Future.delayed(Duration.zero, () async {
      try {
        await getAddressFromCoordinates(lat, lon);
      } catch (e) {
        print('Background address update failed: $e');
      }
    });
  }

  Future<void> checkLocationPermission() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      hasLocationService.value = serviceEnabled;

      if (!serviceEnabled) {
        errorMessage.value =
            'Location services are disabled. Please enable GPS.';
        hasPermission.value = false;
        currentAddress.value = 'GPS disabled';

        Get.snackbar(
          'GPS Required',
          'Please enable location services in your device settings',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => openLocationSettings(),
            child: const Text(
              'Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          errorMessage.value = 'Location permissions are denied';
          hasPermission.value = false;
          currentAddress.value = 'Permission denied';

          Get.snackbar(
            'Permission Required',
            'Location permission is required for attendance tracking',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () => requestPermission(),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        errorMessage.value =
            'Location permissions are permanently denied. Please enable from app settings.';
        hasPermission.value = false;
        currentAddress.value = 'Permission permanently denied';

        Get.snackbar(
          'Permission Blocked',
          'Please enable location permission from app settings',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: const Text(
              'Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      // Permission granted
      hasPermission.value = true;
      errorMessage.value = '';

      // Get location immediately after permission is granted
      await getCurrentLocation();

      Get.snackbar(
        'Location Enabled',
        'Location tracking is now active',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      errorMessage.value = 'Error checking location permission: $e';
      hasPermission.value = false;
      currentAddress.value = 'Permission check failed';
      print('Error checking location permission: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getCurrentLocation() async {
    // Check if we already have a recent location to avoid unnecessary calls
    if (currentLocation.value != null &&
        _lastLocationUpdate != null &&
        DateTime.now().difference(_lastLocationUpdate!).inMinutes < 2) {
      print('Using cached location, last updated: $_lastLocationUpdate');
      return;
    }

    if (!hasPermission.value) {
      await checkLocationPermission();
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      currentAddress.value = 'Getting location...';

      // Try highest accuracy first with longer timeout for best results
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best, // Highest accuracy
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        print('Best accuracy failed, trying high accuracy: $e');
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e2) {
          print('High accuracy failed, trying medium accuracy: $e2');
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          );
        }
      }

      currentLocation.value = position;
      _lastLocationUpdate = DateTime.now();

      // Always display GPS
      locationAccuracy.value = 'GPS';

      // Set coordinates immediately for quick feedback
      currentAddress.value =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      // Get address in background to avoid blocking
      _getAddressAsync(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
      errorMessage.value = 'Error getting location: $e';

      // Try to get last known location as fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: false,
        );
        if (lastPosition != null) {
          currentLocation.value = lastPosition;
          currentAddress.value =
              '${lastPosition.latitude.toStringAsFixed(6)}, ${lastPosition.longitude.toStringAsFixed(6)} (Last Known)';
          locationAccuracy.value = 'GPS';

          // Still try to get address for last known location
          _getAddressAsync(lastPosition.latitude, lastPosition.longitude);
        } else {
          currentAddress.value = 'Location unavailable';
          Get.snackbar(
            'Location Error',
            'Unable to get your location. Please check GPS settings.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } catch (fallbackError) {
        print('Fallback location also failed: $fallbackError');
        currentAddress.value = 'Location unavailable';
        locationAccuracy.value = 'GPS';
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Async address lookup to avoid blocking UI
  void _getAddressAsync(double lat, double lon) {
    Future.delayed(Duration.zero, () async {
      try {
        await getAddressFromCoordinates(lat, lon);
      } catch (e) {
        print('Background address update failed: $e');
        // Don't show error to user for background address lookup
      }
    });
  }

  Future<void> getAddressFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build comprehensive address like React Native version
        final parts = <String>[];

        if (place.name?.isNotEmpty == true && place.name != place.street) {
          parts.add(place.name!);
        }
        if (place.street?.isNotEmpty == true) {
          parts.add(place.street!);
        }
        if (place.subLocality?.isNotEmpty == true) {
          parts.add(place.subLocality!);
        }
        if (place.locality?.isNotEmpty == true) {
          parts.add(place.locality!);
        }
        if (place.administrativeArea?.isNotEmpty == true) {
          parts.add(place.administrativeArea!);
        }

        String formattedAddress = parts.take(3).join(', ');

        if (formattedAddress.isEmpty) {
          formattedAddress =
              '${place.locality ?? 'Unknown'}, ${place.country ?? 'Unknown'}';
        }

        currentAddress.value = formattedAddress;
      }
    } catch (e) {
      print('Error getting address: $e');
      // Keep the coordinate display if address fails
      if (currentLocation.value != null) {
        currentAddress.value =
            '${currentLocation.value!.latitude.toStringAsFixed(6)}, ${currentLocation.value!.longitude.toStringAsFixed(6)}';
      } else {
        currentAddress.value = 'Address not available';
      }
    }
  }

  Future<void> requestPermission() async {
    await checkLocationPermission();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  void refreshLocation() {
    // Only refresh if it's been more than 30 seconds since last update
    if (_lastLocationUpdate != null &&
        DateTime.now().difference(_lastLocationUpdate!).inSeconds < 30) {
      print('Location refreshed recently, skipping');
      Get.snackbar(
        'Info',
        'Location was updated recently',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (hasPermission.value) {
      getCurrentLocation();
    } else {
      checkLocationPermission();
    }
  }

  String getLocationAccuracy() {
    return locationAccuracy.value;
  }

  String getFormattedCoordinates() {
    if (currentLocation.value != null) {
      final lat = currentLocation.value!.latitude.toStringAsFixed(6);
      final lon = currentLocation.value!.longitude.toStringAsFixed(6);
      return '$lat, $lon';
    }
    return 'Not available';
  }

  // Methods for work tracking similar to React Native
  Future<bool> startWork() async {
    try {
      if (!hasPermission.value) {
        await checkLocationPermission();
        if (!hasPermission.value) return false;
      }

      // Get fresh location for work start
      await getCurrentLocation();

      if (currentLocation.value == null) {
        Get.snackbar(
          'Location Required',
          'Unable to get current location for work tracking',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }

      // Start continuous tracking
      await startLocationTracking();

      return true;
    } catch (e) {
      print('Error starting work: $e');
      Get.snackbar(
        'Error',
        'Failed to start work tracking: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<bool> endWork() async {
    try {
      // Stop location tracking
      stopLocationTracking();

      return true;
    } catch (e) {
      print('Error ending work: $e');
      return false;
    }
  }

  // Add location validation methods
  static const double _allowedDistanceInMeters = 10.0;

  // Company/Office location - this should be configurable per company
  // For now, using a default location - update this with actual office coordinates
  static const double _officeLatitude = 28.6139; // Delhi coordinates as example
  static const double _officeLongitude = 77.2090;

  /// Calculate distance between two points in meters using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if current location is within allowed distance from office
  bool isWithinOfficeRadius() {
    if (currentLocation.value == null) return false;

    final distance = calculateDistance(
      currentLocation.value!.latitude,
      currentLocation.value!.longitude,
      _officeLatitude,
      _officeLongitude,
    );

    return distance <= _allowedDistanceInMeters;
  }

  /// Get distance from office in meters
  double getDistanceFromOffice() {
    if (currentLocation.value == null) return double.infinity;

    return calculateDistance(
      currentLocation.value!.latitude,
      currentLocation.value!.longitude,
      _officeLatitude,
      _officeLongitude,
    );
  }

  /// Validate location for attendance
  Future<bool> validateLocationForAttendance() async {
    if (!hasPermission.value) {
      errorMessage.value = 'Location permission required';
      return false;
    }

    if (currentLocation.value == null) {
      await getCurrentLocation();
      if (currentLocation.value == null) {
        errorMessage.value = 'Unable to get current location';
        return false;
      }
    }

    if (!isWithinOfficeRadius()) {
      final distance = getDistanceFromOffice();
      errorMessage.value =
          'You are ${distance.toStringAsFixed(1)}m from office. Please get within ${_allowedDistanceInMeters.toInt()}m to check in.';
      return false;
    }

    return true;
  }

  /// Get office coordinates for map display
  Map<String, double> getOfficeCoordinates() {
    return {'latitude': _officeLatitude, 'longitude': _officeLongitude};
  }
}
