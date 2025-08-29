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
import '../../theme/app_theme.dart';
import '../../widgets/enhanced_attendance_calendar_widget.dart';
import 'employee_profile_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final attendanceController = Get.put(AttendanceController());
  final authController = Get.find<AuthController>();
  final leaveController = Get.put(LeaveRequestController());
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
    _setupLocationTracking();
  }

  Future<void> _setupLocationTracking() async {
    final locationController = Get.find<LocationController>();

    // Start location tracking
    await locationController.getCurrentLocation();

    // Listen for location changes and update map
    ever(locationController.currentLocation, (Position? newLocation) {
      if (newLocation != null && _mapController != null) {
        _animateToUserLocation(newLocation);
      }
    });

    // Auto-refresh location every 10 seconds for real-time tracking
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        locationController.getCurrentLocation();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month, size: 20)),
            Tab(text: 'Leave', icon: Icon(Icons.event_available, size: 20)),
            Tab(text: 'Profile', icon: Icon(Icons.person, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildCalendarTab(),
          _buildLeaveRequestTab(),
          _buildProfileTab(),
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
                color: attendanceController.hasCheckedInToday.value
                    ? Colors.green.withOpacity(0.9)
                    : Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    attendanceController.hasCheckedInToday.value
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    attendanceController.hasCheckedInToday.value
                        ? 'ON DUTY'
                        : 'OFF DUTY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (attendanceController.hasCheckedInToday.value &&
                      attendanceController.checkInTime.value != null)
                    Text(
                      ' - Since ${DateFormat('hh:mm a').format(attendanceController.checkInTime.value!)}',
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
    final locationController = Get.put(LocationController());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Obx(
                      () => Text(
                        locationController.hasPermission.value
                            ? 'GPS tracking active'
                            : 'Location permission required',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => locationController.isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Enhanced map preview with Google Maps
        Obx(
          () => Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Real Google Maps with live location tracking
                  Obx(() {
                    final userLocation =
                        locationController.currentLocation.value;
                    final defaultLocation = const LatLng(
                      28.6139,
                      77.2090,
                    ); // Delhi default

                    return GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        // Auto-zoom to user location when map is ready
                        if (userLocation != null) {
                          _animateToUserLocation(userLocation);
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: userLocation != null
                            ? LatLng(
                                userLocation.latitude,
                                userLocation.longitude,
                              )
                            : defaultLocation,
                        zoom: 16.0,
                      ),
                      markers: _buildRealTimeMarkers(),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                      mapType: MapType.normal,
                      onCameraMove: (CameraPosition position) {
                        // Optional: Handle camera movement
                      },
                    );
                  }),

                  // Loading overlay
                  if (locationController.isLoading.value)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),

                  // Location status overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: locationController.isWithinOfficeRadius()
                            ? Colors.green.withOpacity(0.9)
                            : Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            locationController.isWithinOfficeRadius()
                                ? Icons.check_circle
                                : Icons.warning,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locationController.isWithinOfficeRadius()
                                ? 'In Range'
                                : 'GPS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Address display
        Obx(
          () => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: locationController.hasPermission.value
                  ? Colors.blue.withOpacity(0.05)
                  : Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: locationController.hasPermission.value
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  locationController.hasPermission.value
                      ? Icons.location_on
                      : Icons.location_disabled,
                  color: locationController.hasPermission.value
                      ? Colors.blue[600]
                      : Colors.red[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationController.currentAddress.value,
                    style: TextStyle(
                      fontSize: 12,
                      color: locationController.hasPermission.value
                          ? Colors.blue[700]
                          : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceButtons() {
    final locationController = Get.find<LocationController>();
    return Obx(() {
      final isCheckingLocation = locationController.isLoading.value;
      final isCheckingAttendance = attendanceController.isLoading.value;
      final hasCheckedIn = attendanceController.hasCheckedInToday.value;
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are on an approved leave today. Check-in/out is disabled.',
                      style: TextStyle(
                        color: Colors.orange,
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
                  () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Leave Request',
                  Icons.event_available,
                  Colors.orange,
                  () => _tabController.animateTo(2),
                ),
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: EnhancedAttendanceCalendarWidget(),
    );
  }

  Widget _buildLeaveRequestTab() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.orange),
            SizedBox(height: 20),
            Text(
              'Under Development',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Leave request functionality is being developed.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return const EmployeeProfileScreen();
  }

  // Google Maps helper methods
  void _animateToUserLocation(Position userLocation) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(userLocation.latitude, userLocation.longitude),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  Set<Marker> _buildRealTimeMarkers() {
    final locationController = Get.find<LocationController>();
    Set<Marker> markers = {};

    // Office marker (red marker like Google Maps)
    markers.add(
      const Marker(
        markerId: MarkerId('office'),
        position: LatLng(28.6139, 77.2090), // Office coordinates
        infoWindow: InfoWindow(
          title: 'Office Location',
          snippet: 'Company Office',
        ),
        icon: BitmapDescriptor.defaultMarker, // Red marker
      ),
    );

    // User location marker (blue dot like Google Maps)
    if (locationController.currentLocation.value != null) {
      final userLoc = locationController.currentLocation.value!;
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(userLoc.latitude, userLoc.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current Position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  // Helper methods
  Future<void> _handleCheckIn() async {
    final locationController = Get.find<LocationController>();

    try {
      final userId = authController.currentUser.value?.id;
      if (userId == null) {
        return;
      }

      final isLeave = await attendanceController.isUserOnLeaveToday(userId);
      if (isLeave) {
        Get.snackbar(
          'Check-in Failed',
          'You are on an approved leave today. Cannot check in.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Get current location to update admin
      await locationController.getCurrentLocation();

      // Proceed with check-in (this will automatically send location to admin)
      await attendanceController.checkIn();

      // Refresh today's status to update the UI
      await attendanceController.checkTodayStatus();

      Get.snackbar(
        'Check-in Successful',
        'Your location has been shared with admin. Have a great day!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Check-in Failed',
        'Unable to process check-in. Please try again.',
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

      // Check for an active check-in record
      final isOnDuty = await attendanceController.isUserOnDuty(userId);
      if (!isOnDuty) {
        Get.snackbar(
          'Check-out Failed',
          'You are not currently checked in.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Get current location to update admin
      await locationController.getCurrentLocation();

      // Proceed with check-out
      await attendanceController.checkOut();

      // Refresh today's status to update the UI
      await attendanceController.checkTodayStatus();

      Get.snackbar(
        'Check-out Successful',
        'Your location has been updated to admin',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Check-out Failed',
        'Unable to process check-out. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
