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
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
    _setupLocationTracking();
  }

  Future<void> _setupLocationTracking() async {
    final locationController = Get.put(LocationController());

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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildCalendarTab(),
          _buildLeaveRequestTab(),
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
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              locationController.forceHighAccuracyUpdate();
                            },
                            icon: const Icon(
                              Icons.gps_fixed,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'High Accuracy GPS',
                          ),
                          IconButton(
                            onPressed: () {
                              locationController.refreshLocation();
                            },
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Refresh Location',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Enhanced map preview with Google Maps
        Container(
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
                  final userLocation = locationController.currentLocation.value;
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
                Obx(
                  () => locationController.isLoading.value
                      ? Container(
                          color: Colors.black.withOpacity(0.2),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Location status overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Obx(
                    () => Container(
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
                ),
              ],
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: EnhancedAttendanceCalendarWidget(),
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
        leaveType: leaveController.selectedLeaveType.value!.name,
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Leave Requests',
                  style: TextStyle(
                    fontSize: 18,
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
            const SizedBox(height: 12),
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
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: Colors.grey,
                        ),
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
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final request = leaveController.userLeaveRequests[index];
                  return _buildLeaveRequestItem(request);
                },
              );
            }),
          ],
        ),
      ),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: leaveType.color.withOpacity(0.1),
        child: Icon(leaveType.icon, color: leaveType.color, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              leaveType.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              request.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${DateFormat('MMM dd').format(request.fromDate)} - ${DateFormat('MMM dd, yyyy').format(request.toDate)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              const SizedBox(width: 8),
              Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${request.totalDays} ${request.totalDays == 1 ? 'day' : 'days'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.reason,
              style: TextStyle(color: Colors.grey[700], fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (request.adminComments != null &&
              request.adminComments!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Admin: ${request.adminComments!}',
                style: const TextStyle(fontSize: 10, color: Colors.blue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

      // --- MODIFICATION: Replaced snackbar with a persistent alert dialog ---
      await Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Check-in Successful'),
          content: const Text(
            'You are now ON DUTY. Your location has been shared with the admin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(), // Closes the dialog
              child: const Text('OK'),
            ),
          ],
        ),
        barrierDismissible: false, // User must press OK to dismiss
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

  void _navigateToProfile() {
    Get.to(() => const EmployeeProfileScreen());
  }
}
