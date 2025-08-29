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

      // Simplified query - get all user's attendance records
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Filter locally for today's records
      bool foundTodayCheckin = false;
      DateTime? todayCheckInTime;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();

        // Check if this is today's record
        if (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          // Check if user hasn't checked out yet
          if (data['checkOutTime'] == null) {
            foundTodayCheckin = true;
            if (data['checkInTime'] != null) {
              todayCheckInTime = (data['checkInTime'] as Timestamp).toDate();
            }
            break;
          }
        }
      }

      hasCheckedInToday.value = foundTodayCheckin;
      onDuty.value = foundTodayCheckin; // Update on-duty status

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
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final companyId = userData['companyId'];

      if (companyId == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Start work session with location tracking
      final locationController = Get.find<LocationController>();
      final workStarted = await locationController.startWork();

      if (!workStarted) {
        Get.snackbar(
          'Error',
          'Unable to start work session. Please check location permissions.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Get current location after starting work
      await locationController.getCurrentLocation();

      final attendanceData = {
        'userId': user.uid,
        'userName': userData['name'] ?? 'Unknown User',
        'companyId': companyId,
        'date': Timestamp.fromDate(today),
        'checkInTime': Timestamp.fromDate(now),
        'checkOutTime': null,
        'checkInLocation': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'checkInLatitude': locationController.currentLocation.value?.latitude,
        'checkInLongitude': locationController.currentLocation.value?.longitude,
        'currentLocation': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'currentLatitude': locationController.currentLocation.value?.latitude,
        'currentLongitude': locationController.currentLocation.value?.longitude,
        'lastLocationUpdate': Timestamp.fromDate(now),
        'status': 'on_duty', // Changed to on_duty status
        'totalHours': 0.0,
        'isTracking': true,
        'isOnDuty': true, // New field for on-duty status
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      // Add attendance record
      await _firestore.collection('attendance').add(attendanceData);

      // Send location update to admin via admin notifications collection
      await _sendLocationToAdmin(
        user.uid,
        userData['name'] ?? 'Unknown User',
        companyId,
        locationController,
        now,
      );

      // Update user's current status in users collection for real-time admin updates
      await _firestore.collection('users').doc(user.uid).update({
        'isOnDuty': true,
        'lastCheckIn': Timestamp.fromDate(now),
        'currentLocation': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'currentLatitude': locationController.currentLocation.value?.latitude,
        'currentLongitude': locationController.currentLocation.value?.longitude,
        'lastLocationUpdate': Timestamp.fromDate(now),
        'onDutyStatus': 'checked_in',
        'statusUpdatedAt': Timestamp.fromDate(now),
      });

      // Create admin notification
      await _createAdminNotification(
        companyId,
        '${userData['name']} has checked in',
        'Employee ${userData['name']} started work at ${DateFormat('HH:mm').format(now)}',
        'check_in',
        user.uid,
      );

      hasCheckedInToday.value = true;
      checkInTime.value = now;
      final formatter = DateFormat('hh:mm a');
      lastActivity.value = 'Checked in at ${formatter.format(now)}';
      onDuty.value = true; // Update on-duty status

      // Start live working time tracking
      _startWorkingTimeTimer();

      Get.snackbar(
        'Success',
        'Checked in successfully - Location tracking started',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
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
        snackPosition: SnackPosition.BOTTOM,
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
      if (user == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // End work session and stop location tracking
      final locationController = Get.find<LocationController>();
      await locationController.endWork();

      // Find today's attendance record with simplified query
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Filter locally for today's unchecked out record
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

      if (todayDoc == null) {
        Get.snackbar(
          'Error',
          'No check-in record found for today',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final data = todayDoc.data() as Map<String, dynamic>;
      final originalCheckInTime = (data['checkInTime'] as Timestamp).toDate();

      // Calculate total hours
      final totalHours = now.difference(originalCheckInTime).inMinutes / 60.0;

      // Get final location for checkout
      await locationController.getCurrentLocation();

      await todayDoc.reference.update({
        'checkOutTime': Timestamp.fromDate(now),
        'totalHours': totalHours,
        'checkOutLocation': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'checkOutLatitude': locationController.currentLocation.value?.latitude,
        'checkOutLongitude':
            locationController.currentLocation.value?.longitude,
        'lastLocation': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'lastLatitude': locationController.currentLocation.value?.latitude,
        'lastLongitude': locationController.currentLocation.value?.longitude,
        'lastLocationUpdate': Timestamp.fromDate(now),
        'isTracking': false,
        'isOnDuty': false, // Update on-duty status
        'status': 'completed', // Change status to completed
        'updatedAt': Timestamp.fromDate(now),
      });

      // Update user's current status in users collection
      final userData = data;
      await _firestore.collection('users').doc(user.uid).update({
        'isOnDuty': false,
        'lastCheckOut': Timestamp.fromDate(now),
        'currentLocation': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'currentLatitude': locationController.currentLocation.value?.latitude,
        'currentLongitude': locationController.currentLocation.value?.longitude,
        'lastLocationUpdate': Timestamp.fromDate(now),
        'onDutyStatus': 'checked_out',
        'statusUpdatedAt': Timestamp.fromDate(now),
        'lastWorkDuration': totalHours,
      });

      // Create admin notification for check out
      await _createAdminNotification(
        userData['companyId'],
        '${userData['userName']} has checked out',
        'Employee ${userData['userName']} finished work at ${DateFormat('HH:mm').format(now)} (${totalHours.toStringAsFixed(1)} hours)',
        'check_out',
        user.uid,
      );

      hasCheckedInToday.value = false;
      checkInTime.value = null;
      final formatter = DateFormat('hh:mm a');
      lastActivity.value =
          'Checked out at ${formatter.format(now)} (${totalHours.toStringAsFixed(1)} hours)';
      onDuty.value = false; // Update on-duty status

      // Stop working time tracking
      _stopWorkingTimeTimer();

      Get.snackbar(
        'Success',
        'Checked out successfully - Location tracking stopped\nTotal hours: ${totalHours.toStringAsFixed(1)}',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
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
        snackPosition: SnackPosition.BOTTOM,
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

  // Create admin notification for employee status changes
  Future<void> _createAdminNotification(
    String companyId,
    String title,
    String message,
    String type,
    String employeeId,
  ) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'companyId': companyId,
        'title': title,
        'message': message,
        'type': type, // check_in, check_out, leave_request, etc.
        'employeeId': employeeId,
        'isRead': false,
        'priority': type == 'check_in' ? 'low' : 'medium',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error creating admin notification: $e');
    }
  }

  // Check if user is on approved leave today
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

  // Send location information to admin when employee checks in
  Future<void> _sendLocationToAdmin(
    String userId,
    String userName,
    String companyId,
    LocationController locationController,
    DateTime checkInTime,
  ) async {
    try {
      // Create a notification for admin about employee check-in with location
      final adminNotification = {
        'type': 'employee_checkin',
        'title': 'Employee Check-In Alert',
        'message': '$userName has checked in',
        'employeeId': userId,
        'employeeName': userName,
        'companyId': companyId,
        'checkInTime': Timestamp.fromDate(checkInTime),
        'location': locationController.currentAddress.value.isNotEmpty
            ? locationController.currentAddress.value
            : 'Location not available',
        'latitude': locationController.currentLocation.value?.latitude,
        'longitude': locationController.currentLocation.value?.longitude,
        'accuracy': locationController.currentLocation.value?.accuracy,
        'timestamp': Timestamp.fromDate(checkInTime),
        'isRead': false,
        'priority': 'high',
        'createdAt': Timestamp.fromDate(checkInTime),
      };

      // Add to admin notifications collection
      await _firestore.collection('admin_notifications').add(adminNotification);

      // Also update employee location in real-time tracking collection
      await _firestore.collection('employee_location_tracking').doc(userId).set(
        {
          'userId': userId,
          'userName': userName,
          'companyId': companyId,
          'currentLocation': locationController.currentAddress.value.isNotEmpty
              ? locationController.currentAddress.value
              : 'Location not available',
          'latitude': locationController.currentLocation.value?.latitude,
          'longitude': locationController.currentLocation.value?.longitude,
          'accuracy': locationController.currentLocation.value?.accuracy,
          'isOnDuty': true,
          'lastCheckIn': Timestamp.fromDate(checkInTime),
          'lastUpdated': Timestamp.fromDate(checkInTime),
          'status': 'checked_in',
        },
        SetOptions(merge: true),
      );

      print('Location sent to admin successfully for user: $userName');
    } catch (e) {
      print('Error sending location to admin: $e');
      // Don't throw error to avoid disrupting check-in process
    }
  }
}
