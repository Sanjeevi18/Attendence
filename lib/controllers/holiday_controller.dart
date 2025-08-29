import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/holiday_model.dart';
import '../services/database_service.dart';
import 'auth_controller.dart';

class HolidayController extends GetxController {
  final DatabaseService _databaseService = DatabaseService();
  final AuthController _authController = Get.find<AuthController>();

  // Observable variables
  final RxList<Holiday> holidays = <Holiday>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxMap<DateTime, List<Holiday>> holidayEvents =
      <DateTime, List<Holiday>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadHolidays();
  }

  // Load all holidays for the company
  Future<void> loadHolidays() async {
    try {
      isLoading.value = true;
      error.value = '';

      final companyId = _authController.currentUser.value?.companyId;
      if (companyId == null) {
        throw Exception('No company ID found');
      }

      final holidayList = await _databaseService.getHolidaysByCompany(
        companyId,
      );
      holidays.value = holidayList;

      // Update holiday events for calendar
      await _updateHolidayEvents();
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', 'Failed to load holidays: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // Load holidays for calendar view in a specific date range
  Future<void> loadHolidaysForCalendar(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final companyId = _authController.currentUser.value?.companyId;
      if (companyId == null) return;

      final holidayMap = await _databaseService.getHolidaysForCalendar(
        companyId,
        startDate,
        endDate,
      );

      holidayEvents.value = holidayMap;
    } catch (e) {
      print('Error loading holidays for calendar: $e');
    }
  }

  // Add a new holiday (Admin only)
  Future<bool> addHoliday({
    required String title,
    required String description,
    required DateTime date,
    String type = 'Company',
    bool isRecurring = false,
  }) async {
    try {
      isLoading.value = true;
      error.value = '';

      final currentUser = _authController.currentUser.value;
      if (currentUser == null || !currentUser.isAdmin) {
        throw Exception('Only administrators can add holidays');
      }

      // Check if holiday already exists on this date
      final existingHoliday = await _databaseService.getHolidayByDate(
        currentUser.companyId,
        date,
      );

      if (existingHoliday != null) {
        throw Exception('A holiday already exists on this date');
      }

      final holiday = Holiday(
        id: const Uuid().v4(),
        companyId: currentUser.companyId,
        title: title,
        description: description,
        date: date,
        type: type,
        isRecurring: isRecurring,
        createdAt: DateTime.now(),
        createdBy: currentUser.id,
      );

      await _databaseService.insertHoliday(holiday);
      await loadHolidays(); // Reload the list

      Get.snackbar(
        'Success',
        'Holiday "$title" has been added successfully',
        snackPosition: SnackPosition.BOTTOM,
      );

      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to add holiday: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Update an existing holiday (Admin only)
  Future<bool> updateHoliday(Holiday holiday) async {
    try {
      isLoading.value = true;

      final currentUser = _authController.currentUser.value;
      if (currentUser == null || !currentUser.isAdmin) {
        throw Exception('Only administrators can update holidays');
      }

      await _databaseService.updateHoliday(holiday);
      await loadHolidays(); // Reload the list

      Get.snackbar(
        'Success',
        'Holiday has been updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );

      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to update holiday: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Delete a holiday (Admin only)
  Future<bool> deleteHoliday(String holidayId) async {
    try {
      isLoading.value = true;

      final currentUser = _authController.currentUser.value;
      if (currentUser == null || !currentUser.isAdmin) {
        throw Exception('Only administrators can delete holidays');
      }

      await _databaseService.deleteHoliday(holidayId);
      await loadHolidays(); // Reload the list

      Get.snackbar(
        'Success',
        'Holiday has been deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );

      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to delete holiday: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Check if a specific date is a holiday
  Future<bool> isHoliday(DateTime date) async {
    final companyId = _authController.currentUser.value?.companyId;
    if (companyId == null) return false;

    return await _databaseService.isHoliday(companyId, date);
  }

  // Get holiday for a specific date
  Future<Holiday?> getHolidayForDate(DateTime date) async {
    final companyId = _authController.currentUser.value?.companyId;
    if (companyId == null) return null;

    return await _databaseService.getHolidayByDate(companyId, date);
  }

  // Get holidays for a specific month
  List<Holiday> getHolidaysForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return holidays.where((holiday) {
      return holiday.date.isAfter(
            startOfMonth.subtract(const Duration(days: 1)),
          ) &&
          holiday.date.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();
  }

  // Get holidays by type
  List<Holiday> getHolidaysByType(String type) {
    return holidays.where((holiday) => holiday.type == type).toList();
  }

  // Update holiday events for calendar
  Future<void> _updateHolidayEvents() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, 1, 1); // Start of year
    final endDate = DateTime(now.year, 12, 31); // End of year

    await loadHolidaysForCalendar(startDate, endDate);
  }

  // Get events for a specific date (used by calendar)
  List<Holiday> getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return holidayEvents[dateKey] ?? [];
  }

  // Set selected date
  void setSelectedDate(DateTime date) {
    selectedDate.value = date;
  }

  // Refresh holidays
  Future<void> refreshHolidays() async {
    await loadHolidays();
  }
}
