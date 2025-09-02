import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/location_controller.dart';
import '../../controllers/leave_request_controller.dart';
import '../../models/leave_request_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comprehensive_attendance_calendar_widget.dart';
import '../../utils/snackbar_utils.dart';
import 'employee_profile_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final attendanceController = Get.put(AttendanceController());
  final authController = Get.find<AuthController>();
  final leaveController = Get.put(LeaveRequestController());

  // Google Maps related variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isMapReady = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastLocationUpdate;
  static const Duration _locationUpdateThrottle = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Delay location setup to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupLocationTracking();
    });
  }

  Future<void> _setupLocationTracking() async {
    final locationController = Get.find<LocationController>();

    // Request permissions first
    await _requestLocationPermissions();

    // Start location tracking
    await locationController.getCurrentLocation();

    // Setup real-time location tracking
    _startRealTimeLocationTracking();

    // Auto-refresh location every 30 seconds for fallback
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        locationController.getCurrentLocation();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _requestLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      SnackbarUtils.showWarning(
        'Please enable location services to use this feature',
        title: 'Location Services',
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        SnackbarUtils.showError(
          'Location permissions are required for attendance tracking',
          title: 'Permission Denied',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      SnackbarUtils.showError(
        'Please enable location permissions in settings',
        title: 'Permission Denied Forever',
      );
      return;
    }
  }

  void _startRealTimeLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // Update every 20 meters (increased from 10)
      timeLimit: Duration(seconds: 30), // Max 30 seconds per update
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (mounted) {
              _updateLocationOnMap(position);
              // Trigger location update in controller less frequently
              final locationController = Get.find<LocationController>();
              if (_lastLocationUpdate == null ||
                  DateTime.now().difference(_lastLocationUpdate!) >
                      const Duration(seconds: 30)) {
                locationController.getCurrentLocation();
              }
            }
          },
          onError: (error) {
            print('Location stream error: $error');
          },
        );
  }

  void _updateLocationOnMap(Position position) {
    if (!mounted) return;

    // Throttle location updates to prevent excessive setState calls
    final now = DateTime.now();
    if (_lastLocationUpdate != null &&
        now.difference(_lastLocationUpdate!) < _locationUpdateThrottle) {
      return;
    }
    _lastLocationUpdate = now;

    if (_mapController != null && _isMapReady) {
      try {
        final LatLng newPosition = LatLng(
          position.latitude,
          position.longitude,
        );

        // Update camera position with animation (non-blocking)
        _mapController!.animateCamera(CameraUpdate.newLatLng(newPosition));

        // Update marker with throttling
        if (mounted) {
          setState(() {
            _markers = {
              Marker(
                markerId: const MarkerId('current_location'),
                position: newPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: 'Current Location',
                  snippet:
                      'Lat: ${position.latitude.toStringAsFixed(6)}, '
                      'Lng: ${position.longitude.toStringAsFixed(6)}',
                ),
              ),
            };
          });
        }
      } catch (e) {
        print('Error updating map location: $e');
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await attendanceController.checkTodayStatus();
    await leaveController.loadUserLeaveRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Employee Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          Obx(() {
            final user = authController.currentUser.value;
            return IconButton(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: user?.profileImage != null
                    ? ClipOval(
                        child: Image.network(
                          user!.profileImage!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              user.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        user?.name.substring(0, 1).toUpperCase() ?? 'E',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              onPressed: () => _navigateToProfile(),
              tooltip: 'Profile',
            );
          }),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildCalendarTab(),
          _buildLeaveRequestTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Force refresh calendar when calendar tab is selected
          if (index == 1) {
            // Calendar tab selected, trigger a rebuild
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() {});
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            label: 'Leave',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildEnhancedLocationWidget(),
          const SizedBox(height: 16),
          _buildAttendanceButtons(),
          const SizedBox(height: 16),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        'Welcome, ${authController.currentUser.value?.name ?? 'User'}!',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Have a great day at work!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Duty Status Display
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: attendanceController.onDuty.value
                    ? Colors.black.withOpacity(0.9)
                    : Colors.black54.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    attendanceController.onDuty.value
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    attendanceController.onDuty.value ? 'ON DUTY' : 'OFF DUTY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (attendanceController.onDuty.value &&
                      attendanceController.dutyStartTime.value != null)
                    Text(
                      ' - Since ${DateFormat('hh:mm a').format(attendanceController.dutyStartTime.value!)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedLocationWidget() {
    final locationController = Get.find<LocationController>();

    return Obx(() {
      try {
        final isLoading = locationController.isLoading.value;
        final hasPermission = locationController.hasPermission.value;
        final currentLocation = locationController.currentLocation.value;
        final currentAddress = locationController.currentAddress.value;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade200, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade400, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.map, color: Colors.black87, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Live Location & Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.my_location,
                          color: Colors.black,
                        ),
                        onPressed: () =>
                            locationController.getCurrentLocation(),
                        tooltip: 'Refresh Location',
                      ),
                  ],
                ),
              ),

              // Map Section
              if (!hasPermission)
                Container(
                  height: 200,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_disabled,
                        color: Colors.black54,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Location Permission Required',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable location access to view the map and track attendance',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _requestLocationPermissions(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ),
                )
              else if (currentLocation != null)
                Container(
                  height: 250,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        try {
                          _mapController = controller;
                          _isMapReady = true;

                          // Set initial marker
                          final LatLng initialPosition = LatLng(
                            currentLocation.latitude,
                            currentLocation.longitude,
                          );

                          if (mounted) {
                            setState(() {
                              _markers = {
                                Marker(
                                  markerId: const MarkerId('current_location'),
                                  position: initialPosition,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueRed,
                                  ),
                                  infoWindow: InfoWindow(
                                    title: 'Current Location',
                                    snippet:
                                        'Lat: ${currentLocation.latitude.toStringAsFixed(6)}, '
                                        'Lng: ${currentLocation.longitude.toStringAsFixed(6)}',
                                  ),
                                ),
                              };
                            });
                          }
                        } catch (e) {
                          print('Error initializing map: $e');
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          currentLocation.latitude,
                          currentLocation.longitude,
                        ),
                        zoom: 16.0,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: false,
                      mapType: MapType.normal,
                      onTap: (LatLng position) {
                        // Optionally handle map taps
                      },
                    ),
                  ),
                )
              else if (isLoading)
                Container(
                  height: 200,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Getting your location...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please wait while we locate you',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        color: Colors.grey.shade600,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to get location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please check your internet connection and GPS',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            locationController.getCurrentLocation(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              // Location Details Section
              if (currentLocation != null && currentAddress.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.my_location,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${currentLocation.latitude.toStringAsFixed(6)}, ${currentLocation.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.place,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Updated: ${DateFormat('hh:mm:ss a').format(DateTime.now())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      } catch (e) {
        print('Error in enhanced location widget: $e');
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Column(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(height: 8),
              Text(
                'Location widget error',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Please try refreshing the app',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        );
      }
    });
  }

  Widget _buildAttendanceButtons() {
    final locationController = Get.find<LocationController>();
    return Obx(() {
      final isCheckingLocation = locationController.isLoading.value;
      final isCheckingAttendance = attendanceController.isLoading.value;
      final hasCheckedIn = attendanceController.onDuty.value;
      final onLeave = leaveController.userLeaveRequests.any((request) {
        final today = DateTime.now();
        return request.status.toLowerCase() == 'approved' &&
            today.isAfter(request.fromDate.subtract(const Duration(days: 1))) &&
            today.isBefore(request.toDate.add(const Duration(days: 1)));
      });

      final canCheckIn =
          !hasCheckedIn &&
          !onLeave &&
          !isCheckingAttendance &&
          !isCheckingLocation &&
          locationController.hasPermission.value;
      final canCheckOut =
          hasCheckedIn &&
          !isCheckingAttendance &&
          !isCheckingLocation &&
          locationController.hasPermission.value;

      return Column(
        children: [
          if (onLeave)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.black54),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are on an approved leave today. Check-in/out is disabled.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Check-in button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canCheckIn ? () => _handleCheckIn() : null,
                  icon: isCheckingAttendance && !hasCheckedIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Check-out button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canCheckOut ? () => _handleCheckOut() : null,
                  icon: isCheckingAttendance && hasCheckedIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Check Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'View History',
                  Icons.history,
                  Colors.blue,
                  () => setState(() => _selectedIndex = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Leave Request',
                  Icons.event_available,
                  Colors.orange,
                  () => setState(() => _selectedIndex = 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'High GPS',
                  Icons.gps_fixed,
                  Colors.green,
                  () {
                    final locationController = Get.find<LocationController>();
                    locationController.forceHighAccuracyUpdate();
                    Get.snackbar(
                      'GPS Update',
                      'Fetching high-accuracy location...',
                      icon: const Icon(Icons.gps_fixed, color: Colors.white),
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(), // Empty placeholder for balance
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ComprehensiveAttendanceCalendarWidget(
        key: ValueKey('calendar_${DateTime.now().month}'),
      ),
    );
  }

  Widget _buildLeaveRequestTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryColor.withOpacity(0.05), Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernLeaveHeader(),
            const SizedBox(height: 24),
            _buildLeaveHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLeaveHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Request time off and manage your leaves',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showModernLeaveRequestDialog();
                },
                icon: const Icon(Icons.add_circle, size: 24),
                label: const Text(
                  'Request Leave',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModernLeaveRequestDialog() {
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: Get.width * 0.9,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogHeader(),
                  const SizedBox(height: 20),
                  _buildModernLeaveTypeSection(),
                  const SizedBox(height: 16),
                  _buildModernDateSection(),
                  const SizedBox(height: 16),
                  _buildModernReasonSection(),
                  const SizedBox(height: 20),
                  _buildModernActionButtons(formKey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.event_note, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave Request',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Fill in the details below',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.close, color: Colors.grey),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.withOpacity(0.1),
            shape: const CircleBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildModernLeaveTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Leave Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<LeaveType>(
              value: leaveController.selectedLeaveType.value,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: 'Choose leave type',
              ),
              validator: (value) {
                if (value == null) {
                  return 'Please select a leave type';
                }
                return null;
              },
              items: LeaveType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: type.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(type.icon, color: type.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            type.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                leaveController.selectedLeaveType.value = value;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Obx(
                () => InkWell(
                  onTap: () => _selectDialogFromDate(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            leaveController.fromDate.value != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(leaveController.fromDate.value!)
                                : 'From Date',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(
                () => InkWell(
                  onTap: () => _selectDialogToDate(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            leaveController.toDate.value != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(leaveController.toDate.value!)
                                : 'To Date',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (leaveController.fromDate.value != null &&
              leaveController.toDate.value != null) {
            final days =
                leaveController.toDate.value!
                    .difference(leaveController.fromDate.value!)
                    .inDays +
                1;
            return Text(
              'Total Duration: $days ${days == 1 ? 'day' : 'days'}',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildModernReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Leave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: leaveController.reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Please provide a detailed reason for your leave...',
              contentPadding: EdgeInsets.all(16),
              hintStyle: TextStyle(color: Colors.grey),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a reason for your leave';
              }
              if (value.trim().length < 10) {
                return 'Please provide a more detailed reason (at least 10 characters)';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernActionButtons(GlobalKey<FormState> formKey) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: leaveController.isLoading.value
                  ? null
                  : () {
                      leaveController.selectedLeaveType.value = null;
                      leaveController.fromDate.value = null;
                      leaveController.toDate.value = null;
                      leaveController.reasonController.clear();
                      Get.back();
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: leaveController.isLoading.value
                  ? null
                  : () => _submitDialogLeaveRequest(formKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: leaveController.isLoading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDialogFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: leaveController.fromDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      leaveController.fromDate.value = picked;
      if (leaveController.toDate.value != null &&
          leaveController.toDate.value!.isBefore(picked)) {
        leaveController.toDate.value = null;
      }
    }
  }

  Future<void> _selectDialogToDate() async {
    if (leaveController.fromDate.value == null) {
      Get.snackbar(
        'Error',
        'Please select from date first',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          leaveController.toDate.value ?? leaveController.fromDate.value!,
      firstDate: leaveController.fromDate.value!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      leaveController.toDate.value = picked;
    }
  }

  Future<void> _submitDialogLeaveRequest(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;

    if (leaveController.selectedLeaveType.value == null) {
      Get.snackbar(
        'Error',
        'Please select a leave type',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (leaveController.fromDate.value == null ||
        leaveController.toDate.value == null) {
      Get.snackbar(
        'Error',
        'Please select both dates',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      await leaveController.submitLeaveRequest(
        leaveType: leaveController.selectedLeaveType.value!.displayName,
        fromDate: leaveController.fromDate.value!,
        toDate: leaveController.toDate.value!,
        reason: leaveController.reasonController.text.trim(),
      );
      Get.snackbar(
        'Success',
        'Leave request submitted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Reset form
      leaveController.selectedLeaveType.value = null;
      leaveController.fromDate.value = null;
      leaveController.toDate.value = null;
      leaveController.reasonController.clear();
      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to submit: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildLeaveHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Leave Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            TextButton(
              onPressed: () {
                leaveController.loadUserLeaveRequests();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Status filter options
        _buildStatusFilter(),
        const SizedBox(height: 16),
        Obx(() {
          if (leaveController.isLoading.value) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  strokeWidth: 3,
                ),
              ),
            );
          }

          if (leaveController.error.value.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      leaveController.error.value,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        leaveController.error.value = '';
                        leaveController.loadUserLeaveRequests();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (leaveController.userLeaveRequests.isEmpty) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No leave requests found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaveController.userLeaveRequests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = leaveController.userLeaveRequests[index];
              return _buildLeaveRequestItem(request);
            },
          );
        }),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Obx(() {
      final counts = leaveController.getLeaveRequestCounts();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'All', counts['all'] ?? 0),
            const SizedBox(width: 8),
            _buildFilterChip('pending', 'Pending', counts['pending'] ?? 0),
            const SizedBox(width: 8),
            _buildFilterChip('approved', 'Approved', counts['approved'] ?? 0),
            const SizedBox(width: 8),
            _buildFilterChip('rejected', 'Rejected', counts['rejected'] ?? 0),
          ],
        ),
      );
    });
  }

  Widget _buildFilterChip(String value, String label, int count) {
    return Obx(() {
      final isSelected = leaveController.selectedStatusFilter.value == value;
      return FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        onSelected: (selected) {
          if (selected) {
            leaveController.updateStatusFilter(value);
          }
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    });
  }

  Widget _buildLeaveRequestItem(LeaveRequest request) {
    final statusColor = leaveController.getStatusColor(request.status);
    final leaveType = LeaveType.values.firstWhere(
      (type) => type.name == request.leaveType,
      orElse: () => LeaveType.casual,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: leaveType.color.withOpacity(0.1),
          child: Icon(leaveType.icon, color: leaveType.color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                leaveType.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                request.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('MMM dd').format(request.fromDate)} - ${DateFormat('MMM dd, yyyy').format(request.toDate)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${request.totalDays} ${request.totalDays == 1 ? 'day' : 'days'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (request.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.reason,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (request.adminComments != null &&
                request.adminComments!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Admin: ${request.adminComments!}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: request.status == 'pending'
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(request);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  void _showDeleteConfirmation(LeaveRequest request) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Leave Request'),
        content: const Text(
          'Are you sure you want to delete this leave request?',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await leaveController.deleteLeaveRequest(request.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Future<void> _handleCheckIn() async {
    final locationController = Get.find<LocationController>();

    try {
      final userId = authController.currentUser.value?.id;
      if (userId == null) {
        return;
      }

      // Check if user is on leave today
      final onLeave = leaveController.userLeaveRequests.any((request) {
        final today = DateTime.now();
        return request.status.toLowerCase() == 'approved' &&
            today.isAfter(request.fromDate.subtract(const Duration(days: 1))) &&
            today.isBefore(request.toDate.add(const Duration(days: 1)));
      });

      if (onLeave) {
        Get.snackbar(
          'Cannot Start Duty',
          'You are on an approved leave today. Cannot start duty.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Get current location to update admin
      await locationController.getCurrentLocation();

      // Start duty
      await attendanceController.toggleDuty();

      Get.snackbar(
        'Duty Started',
        'You are now ON DUTY. Your location has been shared with the admin.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Failed to Start Duty',
        'Unable to start duty. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleCheckOut() async {
    final locationController = Get.find<LocationController>();

    try {
      final userId = authController.currentUser.value?.id;
      if (userId == null) {
        return;
      }

      if (!attendanceController.onDuty.value) {
        Get.snackbar(
          'Not On Duty',
          'You are not currently on duty.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Get current location to update admin
      await locationController.getCurrentLocation();

      // End duty
      await attendanceController.toggleDuty();

      Get.snackbar(
        'Duty Ended',
        'You are now OFF DUTY. Your location has been updated to admin.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Failed to End Duty',
        'Unable to end duty. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _navigateToProfile() {
    Get.to(() => const EmployeeProfileScreen());
  }
}
