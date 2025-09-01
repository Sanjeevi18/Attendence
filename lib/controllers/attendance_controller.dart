import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Observable variables for admin dashboard
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

  // Simple attendance tracking - only on/off duty status
  final RxBool onDuty = false.obs;
  final Rxn<DateTime> dutyStartTime = Rxn<DateTime>();
  final RxString currentWorkingTime = ''.obs;

  Timer? _workingTimeTimer;
  Timer? _statsRefreshTimer;

  // Getter for formatted working hours
  String get formattedWorkingHours {
    final hours = employeeWorkingHours.value;
    if (hours == 0) return '0h';
    return '${hours}h';
  }

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

  @override
  void onClose() {
    _workingTimeTimer?.cancel();
    _statsRefreshTimer?.cancel();
    super.onClose();
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
    } finally {
      isLoading.value = false;
    }
  }

  // Simple duty toggle methods
  Future<void> toggleDuty() async {
    if (onDuty.value) {
      await goOffDuty();
    } else {
      await goOnDuty();
    }
  }

  Future<void> goOnDuty() async {
    try {
      isLoading.value = true;
      final user = authController.currentUser.value;
      if (user == null) return;

      final now = DateTime.now();
      onDuty.value = true;
      dutyStartTime.value = now;

      // Start working time timer
      _startWorkingTimeTimer();

      // Create or update attendance record for today
      await _updateAttendanceRecord(user, now, isOnDuty: true);

      // Update user status in Firestore
      await _firestore.collection('users').doc(user.id).update({
        'isOnDuty': true,
        'dutyStartTime': now,
        'lastActivityTime': now,
      });

      Get.snackbar(
        'On Duty',
        'You are now on duty',
        backgroundColor: Colors.black,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      error.value = 'Failed to go on duty: $e';
      Get.snackbar(
        'Error',
        'Failed to go on duty. Please try again.',
        backgroundColor: Colors.black54,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> goOffDuty() async {
    try {
      isLoading.value = true;
      final user = authController.currentUser.value;
      if (user == null) return;

      final now = DateTime.now();
      final startTime = dutyStartTime.value;

      onDuty.value = false;
      _stopWorkingTimeTimer();

      // Update attendance record for today
      await _updateAttendanceRecord(user, now, isOnDuty: false);

      // Update user status in Firestore
      await _firestore.collection('users').doc(user.id).update({
        'isOnDuty': false,
        'dutyEndTime': now,
        'lastActivityTime': now,
      });

      // Calculate total working time for the day
      if (startTime != null) {
        final duration = now.difference(startTime);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;

        Get.snackbar(
          'Off Duty',
          'Total working time: ${hours}h ${minutes}m',
          backgroundColor: Colors.black,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Off Duty',
          'You are now off duty',
          backgroundColor: Colors.black,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      // Reset values
      dutyStartTime.value = null;
      currentWorkingTime.value = '';
    } catch (e) {
      error.value = 'Failed to go off duty: $e';
      Get.snackbar(
        'Error',
        'Failed to go off duty. Please try again.',
        backgroundColor: Colors.black54,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _updateAttendanceRecord(
    UserModel.User user,
    DateTime timestamp, {
    required bool isOnDuty,
  }) async {
    final today = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(today);

    final attendanceRef = _firestore
        .collection('attendance')
        .doc('${user.id}_$dateStr');

    // Get location information
    final locationController = Get.find<LocationController>();
    final currentLocation = locationController.currentLocation.value;
    final currentAddress = locationController.currentAddress.value;

    if (isOnDuty) {
      // Going on duty - create or update with start time and location
      await attendanceRef.set({
        'userId': user.id,
        'companyId': user.companyId,
        'date': dateStr,
        'dutyStartTime': timestamp,
        'checkInLocation': currentLocation != null
            ? {
                'latitude': currentLocation.latitude,
                'longitude': currentLocation.longitude,
              }
            : null,
        'checkInAddress': currentAddress,
        'status': 'present',
        'isOnDuty': true,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    } else {
      // Going off duty - update with end time, location and calculate duration
      final doc = await attendanceRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        final startTime = (data['dutyStartTime'] as Timestamp?)?.toDate();

        if (startTime != null) {
          final duration = timestamp.difference(startTime);
          await attendanceRef.update({
            'dutyEndTime': timestamp,
            'checkOutLocation': currentLocation != null
                ? {
                    'latitude': currentLocation.latitude,
                    'longitude': currentLocation.longitude,
                  }
                : null,
            'checkOutAddress': currentAddress,
            'totalDuration': duration.inMinutes,
            'totalDurationFormatted':
                '${duration.inHours}h ${duration.inMinutes % 60}m',
            'isOnDuty': false,
            'updatedAt': timestamp,
          });
        }
      }
    }
  }

  // Start working time timer
  void _startWorkingTimeTimer() {
    _workingTimeTimer?.cancel();
    _workingTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (dutyStartTime.value != null && onDuty.value) {
        final now = DateTime.now();
        final duration = now.difference(dutyStartTime.value!);
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

  // Check today's status on app start
  Future<void> checkTodayStatus() async {
    try {
      final user = authController.currentUser.value;
      if (user == null) return;

      final today = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(today);

      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc('${user.id}_$dateStr')
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        final isCurrentlyOnDuty = data['isOnDuty'] ?? false;
        onDuty.value = isCurrentlyOnDuty;

        if (isCurrentlyOnDuty && data['dutyStartTime'] != null) {
          dutyStartTime.value = (data['dutyStartTime'] as Timestamp).toDate();
          _startWorkingTimeTimer();
        }
      }
    } catch (e) {
      print('Error checking today status: $e');
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

      // Get attendance records for current month
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where(
            'date',
            isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(monthStart),
          )
          .where('date', isLessThan: DateFormat('yyyy-MM-dd').format(monthEnd))
          .get();

      int presentDays = 0;
      int totalMinutes = 0;

      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'present') {
          presentDays++;
          if (data['totalDuration'] != null) {
            totalMinutes += (data['totalDuration'] as num).toInt();
          }
        }
      }

      final totalHours = (totalMinutes / 60).round();
      employeePresentDays.value = presentDays;
      employeeWorkingHours.value = totalHours;

      // Get leave requests for current month
      final leaveQuery = await _firestore
          .collection('leave_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      int totalLeaveDays = 0;
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        // Calculate days in current month
        DateTime checkDate = fromDate;
        while (checkDate.isBefore(toDate.add(const Duration(days: 1)))) {
          if (checkDate.month == now.month && checkDate.year == now.year) {
            totalLeaveDays++;
          }
          checkDate = checkDate.add(const Duration(days: 1));
        }
      }

      employeeLeaveDays.value = totalLeaveDays;

      // Calculate absent days (working days - present days - leave days)
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final workingDays = _calculateWorkingDays(
        monthStart,
        DateTime(now.year, now.month, daysInMonth),
      );
      employeeAbsentDays.value =
          (workingDays - employeePresentDays.value - employeeLeaveDays.value)
              .clamp(0, workingDays);
    } catch (e) {
      error.value = 'Failed to load employee stats: $e';
    }
  }

  int _calculateWorkingDays(DateTime start, DateTime end) {
    int workingDays = 0;
    DateTime current = start;

    while (current.isBefore(end.add(const Duration(days: 1)))) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  Future<void> loadAdminStats() async {
    try {
      final companyId = authController.currentCompany.value?.id;
      if (companyId == null) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get today's attendance
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('companyId', isEqualTo: companyId)
          .where('date', isEqualTo: today)
          .get();

      int present = 0;
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'present') {
          present++;
        }
      }

      // Get today's leave requests
      final leaveQuery = await _firestore
          .collection('leave_requests')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'approved')
          .get();

      int onLeave = 0;
      final today_dt = DateTime.now();
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        if (today_dt.isAfter(fromDate.subtract(const Duration(days: 1))) &&
            today_dt.isBefore(toDate.add(const Duration(days: 1)))) {
          onLeave++;
        }
      }

      presentToday.value = present;
      onLeaveToday.value = onLeave;
      absentToday.value = (totalEmployees.value - present - onLeave).clamp(
        0,
        totalEmployees.value,
      );
    } catch (e) {
      error.value = 'Failed to load admin stats: $e';
    }
  }

  // Calendar data methods
  Future<Map<String, dynamic>> getAttendanceForDate(DateTime date) async {
    try {
      final user = authController.currentUser.value;
      if (user == null) {
        return {'status': 'absent', 'isOnDuty': false};
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Check if it's today and user is currently on duty
      if (DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr) {
        if (onDuty.value) {
          return {
            'status': 'present',
            'isOnDuty': true,
            'dutyStartTime': dutyStartTime.value,
            'currentDuration': currentWorkingTime.value,
            'checkInTime': dutyStartTime.value != null
                ? DateFormat('hh:mm a').format(dutyStartTime.value!)
                : null,
            'checkOutTime': null,
            'totalDuration': currentWorkingTime.value,
            'checkInAddress': 'Current location',
            'checkOutAddress': null,
          };
        }
      }

      // Fetch attendance record from Firestore
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc('${user.id}_$dateStr')
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;

        final dutyStart = data['dutyStartTime'] != null
            ? (data['dutyStartTime'] as Timestamp).toDate()
            : null;
        final dutyEnd = data['dutyEndTime'] != null
            ? (data['dutyEndTime'] as Timestamp).toDate()
            : null;

        String? totalDuration;
        if (data['totalDurationFormatted'] != null) {
          totalDuration = data['totalDurationFormatted'];
        } else if (data['totalDuration'] != null) {
          final minutes = data['totalDuration'] as int;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          totalDuration = '${hours}h ${mins}m';
        }

        return {
          'status': data['status'] ?? 'absent',
          'isOnDuty': data['isOnDuty'] ?? false,
          'dutyStartTime': dutyStart,
          'dutyEndTime': dutyEnd,
          'checkInTime': dutyStart != null
              ? DateFormat('hh:mm a').format(dutyStart)
              : null,
          'checkOutTime': dutyEnd != null
              ? DateFormat('hh:mm a').format(dutyEnd)
              : null,
          'totalDuration': totalDuration ?? 'N/A',
          'checkInAddress': data['checkInAddress'] ?? 'Location not available',
          'checkOutAddress':
              data['checkOutAddress'] ??
              (dutyEnd != null ? 'Location not available' : null),
          'checkInLocation': data['checkInLocation'],
          'checkOutLocation': data['checkOutLocation'],
        };
      }

      // Check if user was on leave
      if (await _isOnLeaveForDate(date)) {
        return {
          'status': 'leave',
          'isOnDuty': false,
          'checkInTime': null,
          'checkOutTime': null,
          'totalDuration': 'On Leave',
          'checkInAddress': null,
          'checkOutAddress': null,
        };
      }

      // Default absent status
      return {
        'status': 'absent',
        'isOnDuty': false,
        'checkInTime': null,
        'checkOutTime': null,
        'totalDuration': 'N/A',
        'checkInAddress': null,
        'checkOutAddress': null,
      };
    } catch (e) {
      print('Error getting attendance for date: $e');
      return {'status': 'absent', 'isOnDuty': false, 'error': e.toString()};
    }
  }

  // Check if user was on leave for a specific date
  Future<bool> _isOnLeaveForDate(DateTime date) async {
    try {
      final userId = authController.currentUser.value?.id;
      if (userId == null) return false;

      final leaveQuery = await _firestore
          .collection('leave_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        if (date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
            date.isBefore(toDate.add(const Duration(days: 1)))) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking leave for date: $e');
      return false;
    }
  }

  // Get attendance data for multiple dates (useful for calendar month view)
  Future<Map<String, Map<String, dynamic>>> getAttendanceForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, Map<String, dynamic>> attendanceMap = {};

    try {
      final user = authController.currentUser.value;
      if (user == null) return attendanceMap;

      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      // Fetch attendance records for the date range
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.id)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .get();

      // Process attendance records
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String;

        final dutyStart = data['dutyStartTime'] != null
            ? (data['dutyStartTime'] as Timestamp).toDate()
            : null;
        final dutyEnd = data['dutyEndTime'] != null
            ? (data['dutyEndTime'] as Timestamp).toDate()
            : null;

        String? totalDuration;
        if (data['totalDurationFormatted'] != null) {
          totalDuration = data['totalDurationFormatted'];
        } else if (data['totalDuration'] != null) {
          final minutes = data['totalDuration'] as int;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          totalDuration = '${hours}h ${mins}m';
        }

        attendanceMap[dateStr] = {
          'status': data['status'] ?? 'absent',
          'isOnDuty': data['isOnDuty'] ?? false,
          'dutyStartTime': dutyStart,
          'dutyEndTime': dutyEnd,
          'checkInTime': dutyStart != null
              ? DateFormat('hh:mm a').format(dutyStart)
              : null,
          'checkOutTime': dutyEnd != null
              ? DateFormat('hh:mm a').format(dutyEnd)
              : null,
          'totalDuration': totalDuration ?? 'N/A',
          'checkInAddress': data['checkInAddress'] ?? 'Location not available',
          'checkOutAddress':
              data['checkOutAddress'] ??
              (dutyEnd != null ? 'Location not available' : null),
          'checkInLocation': data['checkInLocation'],
          'checkOutLocation': data['checkOutLocation'],
        };
      }

      // Get leave requests for the date range
      final leaveQuery = await _firestore
          .collection('leave_requests')
          .where('userId', isEqualTo: user.id)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        DateTime currentDate = fromDate;
        while (currentDate.isBefore(toDate.add(const Duration(days: 1)))) {
          if (currentDate.isAfter(
                startDate.subtract(const Duration(days: 1)),
              ) &&
              currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
            final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
            if (!attendanceMap.containsKey(dateStr)) {
              attendanceMap[dateStr] = {
                'status': 'leave',
                'isOnDuty': false,
                'checkInTime': null,
                'checkOutTime': null,
                'totalDuration': 'On Leave',
                'checkInAddress': null,
                'checkOutAddress': null,
                'leaveType': data['leaveType'] ?? 'Leave',
                'leaveReason': data['reason'] ?? '',
              };
            }
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      return attendanceMap;
    } catch (e) {
      print('Error getting attendance for date range: $e');
      return attendanceMap;
    }
  }

  // Legacy method for backwards compatibility
  Map<String, dynamic> getAttendanceForDateSync(DateTime date) {
    // This will be called by the calendar widget to get attendance data for a specific date
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Return simple status based on current state
    if (DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr) {
      return {
        'status': onDuty.value ? 'present' : 'absent',
        'isOnDuty': onDuty.value,
        'dutyStartTime': dutyStartTime.value,
        'currentDuration': currentWorkingTime.value,
      };
    }

    // For other dates, return default
    return {'status': 'absent', 'isOnDuty': false};
  }

  // Check if user is on approved leave today
  Future<bool> isOnLeaveToday() async {
    try {
      final userId = authController.currentUser.value?.id;
      if (userId == null) return false;

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
              'dutyStartTime': data['dutyStartTime'],
              'lastActivityTime': data['lastActivityTime'],
            };
          }).toList();
        });
  }

  // Missing admin methods
  Future<void> refreshStats() async {
    await loadAdminStats();
    await loadEmployeeData();
  }

  Future<Map<String, dynamic>> getAllEmployeesDutyStatus() async {
    try {
      final companyId = authController.currentCompany.value?.id;
      if (companyId == null) return {};

      final snapshot = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .where('isAdmin', isEqualTo: false)
          .get();

      Map<String, dynamic> dutyStatus = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        dutyStatus[doc.id] = {
          'isOnDuty': data['isOnDuty'] ?? false,
          'dutyStartTime': data['dutyStartTime'],
          'lastLocation': data['lastLocation'],
        };
      }
      return dutyStatus;
    } catch (e) {
      print('Error getting duty status: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>?> getEmployeeLocationData(
    String employeeId,
  ) async {
    try {
      final doc = await _firestore.collection('users').doc(employeeId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'lastLocation': data['lastLocation'],
        'lastLocationAddress': data['lastLocationAddress'],
        'lastActivityTime': data['lastActivityTime'],
        'isOnDuty': data['isOnDuty'] ?? false,
      };
    } catch (e) {
      print('Error getting employee location: $e');
      return null;
    }
  }

  Future<void> removeEmployee(String employeeId) async {
    try {
      // Remove from Firestore
      await _firestore.collection('users').doc(employeeId).delete();

      // Remove from local list
      allEmployees.removeWhere((employee) => employee.id == employeeId);
      totalEmployees.value = allEmployees.length;

      // Refresh stats
      await refreshStats();
    } catch (e) {
      print('Error removing employee: $e');
      throw e;
    }
  }
}
