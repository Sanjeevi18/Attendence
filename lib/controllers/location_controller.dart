import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'auth_controller.dart';

class LocationController extends GetxController {
  var isLoading = false.obs;
  var hasPermission = false.obs;
  var hasLocationService = false.obs;
  var currentLocation = Rxn<Position>();
  var currentAddress = ''.obs;
  var errorMessage = ''.obs;
  var isTracking = false.obs;

  StreamSubscription<Position>? _positionSubscription;
  final AuthController _authController = Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    checkLocationPermission();
  }

  @override
  void onClose() {
    stopLocationTracking();
    super.onClose();
  }

  Future<void> startLocationTracking() async {
    if (isTracking.value) return;

    try {
      if (!hasPermission.value) {
        await checkLocationPermission();
        if (!hasPermission.value) return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              currentLocation.value = position;
              await getAddressFromCoordinates(
                position.latitude,
                position.longitude,
              );
              await _updateFirestoreLocation(position);
            },
            onError: (error) {
              errorMessage.value = 'Location tracking error: $error';
            },
          );

      isTracking.value = true;
    } catch (e) {
      errorMessage.value = 'Error starting location tracking: $e';
    }
  }

  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    isTracking.value = false;
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

  Future<void> checkLocationPermission() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      hasLocationService.value = serviceEnabled;

      if (!serviceEnabled) {
        errorMessage.value = 'Location services are disabled.';
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          errorMessage.value = 'Location permissions are denied';
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        errorMessage.value =
            'Location permissions are permanently denied, we cannot request permissions.';
        return;
      }

      hasPermission.value = true;
      await getCurrentLocation();
    } catch (e) {
      errorMessage.value = 'Error checking location permission: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation.value = position;
      await getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      errorMessage.value = 'Error getting current location: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getAddressFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Create short and accurate address
        final parts = <String>[];

        if (place.street?.isNotEmpty == true) {
          parts.add(place.street!);
        }
        if (place.subLocality?.isNotEmpty == true) {
          parts.add(place.subLocality!);
        }
        if (place.locality?.isNotEmpty == true) {
          parts.add(place.locality!);
        }

        currentAddress.value = parts
            .take(2)
            .join(', '); // Show only first 2 parts
        if (currentAddress.value.isEmpty) {
          currentAddress.value =
              '${place.locality ?? ''}, ${place.country ?? ''}';
        }
      }
    } catch (e) {
      currentAddress.value = 'Address not available';
      print('Error getting address: $e');
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
    if (hasPermission.value) {
      getCurrentLocation();
    } else {
      checkLocationPermission();
    }
  }

  String getLocationAccuracy() {
    if (currentLocation.value != null) {
      final accuracy = currentLocation.value!.accuracy;
      if (accuracy < 5) return 'High';
      if (accuracy < 15) return 'Medium';
      return 'Low';
    }
    return 'Unknown';
  }

  String getFormattedCoordinates() {
    if (currentLocation.value != null) {
      final lat = currentLocation.value!.latitude.toStringAsFixed(6);
      final lon = currentLocation.value!.longitude.toStringAsFixed(6);
      return '$lat, $lon';
    }
    return 'Not available';
  }
}
