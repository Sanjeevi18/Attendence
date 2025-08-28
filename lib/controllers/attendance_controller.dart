import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'auth_controller.dart';

class AttendanceController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController authController = Get.find<AuthController>();

  // Observable variables
  final RxList<User> allEmployees = <User>[].obs;
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
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Reset values
      presentToday.value = 0;
      absentToday.value = 0;
      onLeaveToday.value = 0;

      // Load actual attendance data from Firebase
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('companyId', isEqualTo: companyId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayEnd))
          .get();

      final leaveQuery = await _firestore
          .collection('leaves')
          .where('companyId', isEqualTo: companyId)
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('status', isEqualTo: 'approved')
          .get();

      // Count present employees
      presentToday.value = attendanceQuery.docs.length;

      // Count employees on leave
      onLeaveToday.value = leaveQuery.docs.length;

      // Calculate absent (total - present - on leave)
      absentToday.value =
          totalEmployees.value - presentToday.value - onLeaveToday.value;

      // Ensure no negative values
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

      // Load attendance data for current employee
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('date', isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      // Load leave data for current employee
      final leaveQuery = await _firestore
          .collection('leaves')
          .where('userId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .where(
            'startDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startDate', isLessThan: Timestamp.fromDate(monthEnd))
          .where('status', isEqualTo: 'approved')
          .get();

      // Calculate present days and working hours
      int totalHours = 0;
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        if (data['checkOut'] != null) {
          final checkIn = (data['checkIn'] as Timestamp).toDate();
          final checkOut = (data['checkOut'] as Timestamp).toDate();
          final hoursWorked = checkOut.difference(checkIn).inHours;
          totalHours += hoursWorked;
        }
      }

      employeePresentDays.value = attendanceQuery.docs.length;
      employeeWorkingHours.value = totalHours;

      // Calculate leave days
      int totalLeaveDays = 0;
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();
        totalLeaveDays += endDate.difference(startDate).inDays + 1;
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
}
