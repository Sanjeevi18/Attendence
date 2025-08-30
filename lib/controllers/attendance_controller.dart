import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/user_model.dart' as UserModel;
import '../services/firebase_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';

class AttendanceController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController authController = Get.find<AuthController>();

  // Observable variables
  final RxList<UserModel.User> allEmployees = <UserModel.User>[].obs;
  final RxInt totalEmployees = 0.obs;
  final RxInt presentToday = 0.obs;
  final RxInt absentToday = 0.obs;
  final RxInt onLeaveToday = 0.obs;

  // Employee specific stats
  final RxInt employeePresentDays = 0.obs;
  final RxInt employeeAbsentDays = 0.obs;
  final RxInt employeeLeaveDays = 0.obs;
  final RxInt employeeWorkingHours = 0.obs;

  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadEmployeeData();
    checkTodayStatus();
    if (authController.currentUser.value?.isAdmin == true) {
      loadAdminStats();
    } else {
      loadEmployeeStats();
    }
  }

  Future<void> loadEmployeeData() async {
    try {
      isLoading.value = true;
      final companyId = authController.currentCompany.value?.id;
      if (companyId != null) {
        final employees = await FirebaseService.getUsersByCompany(companyId);
        allEmployees.value = employees;
        totalEmployees.value = employees.length;
      }
    } catch (e) {
      error.value = 'Failed to load employee data: $e';
      print('Error loading employees: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAdminStats() async {
    try {
      final companyId = authController.currentCompany.value?.id;
      if (companyId == null) return;

      // Get today's date
      final today = DateTime.now();

      // Reset values
      presentToday.value = 0;
      absentToday.value = 0;
      onLeaveToday.value = 0;

      // Load attendance data with simplified query
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('companyId', isEqualTo: companyId)
          .get();

      // Filter locally for today's attendance
      int todayPresent = 0;
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          todayPresent++;
        }
      }

      // Load leave data with simplified query
      final leaveQuery = await _firestore
          .collection('leaves')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Filter locally for today's leaves
      int todayOnLeave = 0;
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();
        if (today.isAfter(startDate.subtract(const Duration(days: 1))) &&
            today.isBefore(endDate.add(const Duration(days: 1)))) {
          todayOnLeave++;
        }
      }

      presentToday.value = todayPresent;
      onLeaveToday.value = todayOnLeave;

      // Calculate absent (total - present - on leave)
      absentToday.value =
          totalEmployees.value - presentToday.value - onLeaveToday.value;

      // Ensure no negative values
      if (absentToday.value < 0) absentToday.value = 0;
      if (absentToday.value < 0) absentToday.value = 0;
    } catch (e) {
      error.value = 'Failed to load admin stats: $e';
      print('Error loading admin stats: $e');
    }
  }

  Future<void> loadEmployeeStats() async {
    try {
      final userId = authController.currentUser.value?.id;
      final companyId = authController.currentCompany.value?.id;
      if (userId == null || companyId == null) return;

      // Get current month's data
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      // Reset values
      employeePresentDays.value = 0;
      employeeAbsentDays.value = 0;
      employeeLeaveDays.value = 0;
      employeeWorkingHours.value = 0;

      // Load attendance data with simplified query
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .get();

      // Filter locally for current month and calculate stats
      int totalHours = 0;
      int presentDays = 0;
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();

        // Check if date is in current month
        if (date.year == now.year && date.month == now.month) {
          presentDays++;

          // Calculate working hours if checkout exists
          if (data['checkOut'] != null) {
            final checkIn = (data['checkIn'] as Timestamp).toDate();
            final checkOut = (data['checkOut'] as Timestamp).toDate();
            final hoursWorked = checkOut.difference(checkIn).inHours;
            totalHours += hoursWorked;
          }
        }
      }

      employeePresentDays.value = presentDays;
      employeeWorkingHours.value = totalHours;

      // Load leave data with simplified query
      final leaveQuery = await _firestore
          .collection('leaves')
          .where('userId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'approved')
          .get();

      // Filter locally for current month leaves
      int totalLeaveDays = 0;
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();

        // Check if leave overlaps with current month
        if ((startDate.year == now.year && startDate.month == now.month) ||
            (endDate.year == now.year && endDate.month == now.month) ||
            (startDate.isBefore(monthStart) && endDate.isAfter(monthEnd))) {
          // Calculate days within current month
          final leaveStart = startDate.isBefore(monthStart)
              ? monthStart
              : startDate;
          final leaveEnd = endDate.isAfter(monthEnd) ? monthEnd : endDate;
          totalLeaveDays += leaveEnd.difference(leaveStart).inDays + 1;
        }
      }
      employeeLeaveDays.value = totalLeaveDays;

      // Calculate working days in month (excluding weekends)
      int workingDays = 0;
      for (
        int day = 1;
        day <= DateTime(now.year, now.month + 1, 0).day;
        day++
      ) {
        final date = DateTime(now.year, now.month, day);
        if (date.weekday != DateTime.saturday &&
            date.weekday != DateTime.sunday) {
          workingDays++;
        }
      }

      // Calculate absent days (working days - present - leave)
      employeeAbsentDays.value =
          workingDays - employeePresentDays.value - employeeLeaveDays.value;
      if (employeeAbsentDays.value < 0) employeeAbsentDays.value = 0;
    } catch (e) {
      error.value = 'Failed to load employee stats: $e';
      print('Error loading employee stats: $e');
    }
  }

  Future<void> refreshStats() async {
    await loadEmployeeData();
    if (authController.currentUser.value?.isAdmin == true) {
      await loadAdminStats();
    } else {
      await loadEmployeeStats();
    }
  }

  // Get formatted working hours for display
  String get formattedWorkingHours {
    return '${employeeWorkingHours.value}h';
  }

  // Auto-refresh statistics every minute when on duty
  Timer? _statsRefreshTimer;

  void _startStatisticsAutoRefresh() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (onDuty.value) {
        loadEmployeeStats(); // Refresh stats while on duty
      }
    });
  }

  void _stopStatisticsAutoRefresh() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = null;
  }

  // Attendance tracking
  final RxBool hasCheckedInToday = false.obs;
  final RxString lastActivity = ''.obs;
  final RxString currentWorkingTime = ''.obs;
  final Rxn<DateTime> checkInTime = Rxn<DateTime>();
  // New on-duty status field
  final RxBool onDuty = false.obs;

  Timer? _workingTimeTimer;

  @override
  void onClose() {
    _workingTimeTimer?.cancel();
    _statsRefreshTimer?.cancel();
    super.onClose();
  }

  // Start working time timer
  void _startWorkingTimeTimer() {
    _workingTimeTimer?.cancel();
    _workingTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (checkInTime.value != null) {
        final now = DateTime.now();
        final duration = now.difference(checkInTime.value!);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        currentWorkingTime.value = '${hours}h ${minutes}m';
      }
    });
  }

  // Stop working time timer
  void _stopWorkingTimeTimer() {
    _workingTimeTimer?.cancel();
    currentWorkingTime.value = '';
  }

  // Check if user has checked in today
  Future<void> checkTodayStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check for today's attendance record without endTime (still checked in)
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('employeeId', isEqualTo: user.uid)
          .where('date', isEqualTo: todayStr)
          .where('endTime', isEqualTo: null)
          .get();

      bool foundTodayCheckin = querySnapshot.docs.isNotEmpty;
      DateTime? todayCheckInTime;

      if (foundTodayCheckin) {
        final data = querySnapshot.docs.first.data();
        if (data['startTime'] != null) {
          todayCheckInTime = (data['startTime'] as Timestamp).toDate();
        }
      }

      hasCheckedInToday.value = foundTodayCheckin;
      onDuty.value = foundTodayCheckin;

      if (hasCheckedInToday.value && todayCheckInTime != null) {
        checkInTime.value = todayCheckInTime;
        final formatter = DateFormat('hh:mm a');
        lastActivity.value =
            'Checked in at ${formatter.format(todayCheckInTime)}';
        // Start timer for live tracking
        _startWorkingTimeTimer();
      }
    } catch (e) {
      print('Error checking today status: $e');
    }
  }

  Future<void> checkIn() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar(
          'Error',
          'User not authenticated',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Get user data from AuthController instead of Firestore
      final currentUser = authController.currentUser.value;
      if (currentUser == null) {
        Get.snackbar(
          'Error',
          'User data not found. Please login again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final companyId = currentUser.companyId;
      if (companyId.isEmpty) {
        Get.snackbar(
          'Error',
          'Company information not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Check if already checked in today
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final existingAttendance = await _firestore
          .collection('attendance')
          .where('employeeId', isEqualTo: user.uid)
          .where('date', isEqualTo: todayStr)
          .where('endTime', isEqualTo: null)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        Get.snackbar(
          'Already Checked In',
          'You are already checked in for today',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Get current location data from LocationController (without changing location code)
      final locationController = Get.find<LocationController>();
      final currentLocation = locationController.currentLocation.value;
      final currentAddress = locationController.currentAddress.value;

      Map<String, dynamic> locationData = {};
      if (currentLocation != null) {
        locationData = {
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
          'address': currentAddress,
          'timestamp': FieldValue.serverTimestamp(),
        };
      }

      // 1. Update employee status to on_duty (like React Native startWork)
      await _firestore.collection('employees').doc(user.uid).set({
        'isActive': true,
        'lastUpdated': FieldValue.serverTimestamp(),
        'status': 'on_duty',
        'statusMessage': 'Employee is on duty',
        'employeeName': currentUser.name,
        'department': currentUser.department ?? 'Unknown',
        'currentLocation': locationData,
      }, SetOptions(merge: true));

      // 2. Update employee status collection (like React Native)
      await _firestore.collection('employeeStatus').doc(user.uid).set({
        'employeeId': user.uid,
        'employeeName': currentUser.name,
        'department': currentUser.department ?? 'Unknown',
        'companyId': currentUser.companyId,
        'isOnDuty': true,
        'status': 'On Duty',
        'location': locationData.isNotEmpty
            ? {
                'latitude': locationData['latitude'],
                'longitude': locationData['longitude'],
                'address': locationData['address'],
              }
            : {},
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Create attendance record (like React Native)
      await _firestore.collection('attendance').add({
        'employeeId': user.uid,
        'employeeName': currentUser.name,
        'startTime': FieldValue.serverTimestamp(),
        'date': todayStr,
        'endTime': null,
        'status': 'Present',
        'location': locationData,
      });

      // 4. Start location tracking (preserving existing location code)
      await locationController.startLocationTracking();

      // Update local state
      hasCheckedInToday.value = true;
      checkInTime.value = today;
      final formatter = DateFormat('hh:mm a');
      lastActivity.value = 'Checked in at ${formatter.format(today)}';
      onDuty.value = true;

      // Start live working time tracking and statistics refresh
      _startWorkingTimeTimer();
      _startStatisticsAutoRefresh();

      Get.snackbar(
        'Success',
        'Checked in successfully! Your location is being tracked.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Refresh stats
      await loadEmployeeStats();
    } catch (e) {
      print('Error checking in: $e');
      Get.snackbar(
        'Error',
        'Failed to check in: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkOut() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.snackbar(
          'Error',
          'User not authenticated',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Check if not checked in - look for today's attendance without checkout
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final existingAttendance = await _firestore
          .collection('attendance')
          .where('employeeId', isEqualTo: user.uid)
          .where('date', isEqualTo: todayStr)
          .get();

      print(
        'Found ${existingAttendance.docs.length} attendance records for today',
      );

      // Find attendance record without checkout time
      DocumentSnapshot? activeAttendance;
      for (var doc in existingAttendance.docs) {
        // ignore: unnecessary_cast
        final data = doc.data() as Map<String, dynamic>;
        print('Attendance record: ${data.keys.toList()}');
        print(
          'checkOutTime: ${data['checkOutTime']}, endTime: ${data['endTime']}',
        );

        // Check if user hasn't checked out yet (either field being null means still checked in)
        if (data['checkOutTime'] == null || data['endTime'] == null) {
          activeAttendance = doc;
          print('Found active attendance record');
          break;
        }
      }

      if (activeAttendance == null) {
        Get.snackbar(
          'Not Checked In',
          'You are not currently checked in',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // 1. Stop location tracking first (like React Native endWork)
      final locationController = Get.find<LocationController>();
      locationController.stopLocationTracking();

      // 2. Update employee status to off_duty (like React Native)
      await _firestore.collection('employees').doc(user.uid).update({
        'isActive': false,
        'lastUpdated': FieldValue.serverTimestamp(),
        'status': 'off_duty',
        'statusMessage': 'Employee shift ended',
      });

      // 3. Update employee status collection (like React Native)
      await _firestore.collection('employeeStatus').doc(user.uid).set({
        'isOnDuty': false,
        'status': 'Off Duty',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Update attendance record with end time (like React Native)
      // ignore: unnecessary_cast
      final attendanceData = activeAttendance.data() as Map<String, dynamic>;
      final startTime = (attendanceData['startTime'] as Timestamp).toDate();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final totalHours = duration.inMinutes / 60.0;

      await activeAttendance.reference.update({
        'endTime': FieldValue.serverTimestamp(),
        'checkOutTime': FieldValue.serverTimestamp(),
        'totalHours': totalHours,
        'duration': '${duration.inHours}h ${duration.inMinutes % 60}m',
      });

      // Update local state
      hasCheckedInToday.value = false;
      checkInTime.value = null;
      final formatter = DateFormat('hh:mm a');
      lastActivity.value = 'Checked out at ${formatter.format(today)}';
      onDuty.value = false;

      // Stop working time tracking and statistics refresh
      _stopWorkingTimeTimer();
      _stopStatisticsAutoRefresh();

      Get.snackbar(
        'Success',
        'Checked out successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Refresh stats
      await loadEmployeeStats();
    } catch (e) {
      print('Error checking out: $e');
      Get.snackbar(
        'Error',
        'Failed to check out: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Update current location for checked-in users
  Future<void> updateCurrentLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !hasCheckedInToday.value) return;

      final today = DateTime.now();

      // Find today's active attendance record with simplified query
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Filter locally for today's active record
      DocumentSnapshot? todayDoc;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();

        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day &&
            data['checkOutTime'] == null) {
          todayDoc = doc;
          break;
        }
      }

      if (todayDoc != null) {
        final locationController = Get.find<LocationController>();
        await locationController.getCurrentLocation();

        if (locationController.currentAddress.value.isNotEmpty) {
          await todayDoc.reference.update({
            'currentLocation': locationController.currentAddress.value,
            'currentLatitude':
                locationController.currentLocation.value?.latitude,
            'currentLongitude':
                locationController.currentLocation.value?.longitude,
            'lastLocationUpdate': Timestamp.fromDate(DateTime.now()),
          });
        }
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Get employee location data for admin
  Future<Map<String, dynamic>?> getEmployeeLocationData(String userId) async {
    try {
      final today = DateTime.now();

      // Get all attendance records for user with simplified query
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter locally for today's records
      DocumentSnapshot? todayActiveDoc;
      DocumentSnapshot? todayLastDoc;

      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();

        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          if (data['checkOutTime'] == null) {
            // User is currently checked in
            todayActiveDoc = doc;
            break;
          } else {
            // Most recent checked out record for today
            todayLastDoc = doc;
          }
        }
      }

      if (todayActiveDoc != null) {
        // User is checked in - return current location
        final data = todayActiveDoc.data() as Map<String, dynamic>;
        return {
          'isActive': true,
          'location': data['currentLocation'] ?? 'Location not available',
          'latitude': data['currentLatitude'],
          'longitude': data['currentLongitude'],
          'lastUpdate': data['lastLocationUpdate'],
          'checkInTime': data['checkInTime'],
        };
      } else if (todayLastDoc != null) {
        // User checked out today - return last known location
        final data = todayLastDoc.data() as Map<String, dynamic>;
        return {
          'isActive': false,
          'location':
              data['lastLocation'] ??
              data['checkOutLocation'] ??
              'No location data',
          'latitude': data['lastLatitude'] ?? data['checkOutLatitude'],
          'longitude': data['lastLongitude'] ?? data['checkOutLongitude'],
          'lastUpdate': data['lastLocationUpdate'] ?? data['checkOutTime'],
          'checkOutTime': data['checkOutTime'],
        };
      } else {
        // No attendance record for today - get most recent
        final lastQuery = await _firestore
            .collection('attendance')
            .where('userId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .limit(1)
            .get();

        if (lastQuery.docs.isNotEmpty) {
          final data = lastQuery.docs.first.data();
          return {
            'isActive': false,
            'location':
                data['lastLocation'] ??
                data['checkOutLocation'] ??
                'No location data',
            'latitude': data['lastLatitude'] ?? data['checkOutLatitude'],
            'longitude': data['lastLongitude'] ?? data['checkOutLongitude'],
            'lastUpdate': data['lastLocationUpdate'] ?? data['checkOutTime'],
            'checkOutTime': data['checkOutTime'],
          };
        }
      }
    } catch (e) {
      print('Error getting employee location: $e');
    }

    return null;
  }

  // Remove employee
  Future<void> removeEmployee(String userId) async {
    try {
      isLoading.value = true;

      // Delete user document
      await _firestore.collection('users').doc(userId).delete();

      // Delete all attendance records
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in attendanceQuery.docs) {
        await doc.reference.delete();
      }

      // Delete all leave records
      final leaveQuery = await _firestore
          .collection('leaves')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in leaveQuery.docs) {
        await doc.reference.delete();
      }

      // Refresh employee data
      await loadEmployeeData();
      await loadAdminStats();

      Get.snackbar(
        'Success',
        'Employee removed successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error removing employee: $e');
      Get.snackbar(
        'Error',
        'Failed to remove employee: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Calendar related methods
  List<Map<String, dynamic>> getEventsForDate(DateTime? date) {
    if (date == null) return [];

    // Return sample events for now - can be expanded to load from Firebase
    return [
      {
        'title': 'Team Meeting',
        'description': 'Weekly team sync',
        'time': '10:00 AM',
        'type': 'meeting',
      },
    ];
  }

  // Check if user is currently on duty (checked in but not checked out)
  Future<bool> isUserOnDuty(String userId) async {
    try {
      final today = DateTime.now();

      // Simplified query to get all user's attendance records
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter locally for today's active records
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();

        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day &&
            data['checkOutTime'] == null) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking duty status for user $userId: $e');
      return false;
    }
  }

  // Get real-time duty status for all employees
  Future<Map<String, bool>> getAllEmployeesDutyStatus() async {
    final dutyStatus = <String, bool>{};

    try {
      for (final employee in allEmployees) {
        dutyStatus[employee.id] = await isUserOnDuty(employee.id);
      }
    } catch (e) {
      print('Error getting all employees duty status: $e');
    }

    return dutyStatus;
  }

  // Get real-time employee status for admin dashboard
  Future<bool> isUserOnLeaveToday(String userId) async {
    try {
      final today = DateTime.now();

      final leaveQuery = await _firestore
          .collection('leave_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        // Check if today is within the leave period
        if (today.isAfter(fromDate.subtract(const Duration(days: 1))) &&
            today.isBefore(toDate.add(const Duration(days: 1)))) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking leave status: $e');
      return false;
    }
  }

  // Get real-time employee status for admin dashboard
  Stream<List<Map<String, dynamic>>> getEmployeeStatusStream() {
    return _firestore
        .collection('users')
        .where('companyId', isEqualTo: authController.currentCompany.value?.id)
        .where('isAdmin', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'],
              'email': data['email'],
              'isOnDuty': data['isOnDuty'] ?? false,
              'currentLocation':
                  data['currentLocation'] ?? 'Location not available',
              'lastLocationUpdate': data['lastLocationUpdate'],
              'onDutyStatus': data['onDutyStatus'] ?? 'offline',
              'statusUpdatedAt': data['statusUpdatedAt'],
            };
          }).toList();
        });
  }
}
