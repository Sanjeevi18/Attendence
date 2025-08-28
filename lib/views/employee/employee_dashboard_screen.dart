import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/holiday_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/shared_calendar_widget.dart';
import '../../models/holiday_model.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final HolidayController holidayController = Get.put(HolidayController());
  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => holidayController.refreshHolidays(),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Get.toNamed('/employee-profile');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 16),
            _buildAttendanceQuickActions(),
            const SizedBox(height: 16),
            _buildCalendarSection(),
            const SizedBox(height: 16),
            _buildUpcomingHolidays(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Obx(() {
      final user = authController.currentUser.value;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.indigo, Colors.indigoAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    user?.name ?? 'Employee',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAttendanceQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
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
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Check In',
                  Icons.login,
                  Colors.green,
                  () => _handleCheckIn(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Check Out',
                  Icons.logout,
                  Colors.orange,
                  () => _handleCheckOut(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'View Timesheet',
                  Icons.schedule,
                  Colors.blue,
                  () => _viewTimesheet(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Request Leave',
                  Icons.event_busy,
                  Colors.purple,
                  () => _requestLeave(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Calendar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'View company holidays and important dates',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        SharedCalendarWidget(
          showHolidayDetails: true,
          readOnly: true, // Employees can view but not edit
          onDateSelected: (date) {
            // Handle date selection if needed
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingHolidays() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.celebration, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text(
                'Upcoming Holidays',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (holidayController.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final upcomingHolidays = _getUpcomingHolidays();

            if (upcomingHolidays.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No upcoming holidays in the next 30 days',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              );
            }

            return Column(
              children: upcomingHolidays
                  .map((holiday) => _buildUpcomingHolidayCard(holiday))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUpcomingHolidayCard(Holiday holiday) {
    final daysUntil = holiday.date.difference(DateTime.now()).inDays;
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getHolidayTypeColor(holiday.type).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getHolidayTypeColor(holiday.type).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getHolidayTypeColor(holiday.type),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getHolidayTypeIcon(holiday.type),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(holiday.date),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (holiday.description.isNotEmpty)
                  Text(
                    holiday.description,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.red
                  : isTomorrow
                  ? Colors.orange
                  : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isToday
                  ? 'Today'
                  : isTomorrow
                  ? 'Tomorrow'
                  : '$daysUntil days',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Holiday> _getUpcomingHolidays() {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    return holidayController.holidays
        .where(
          (holiday) =>
              holiday.date.isAfter(now.subtract(const Duration(days: 1))) &&
              holiday.date.isBefore(
                thirtyDaysFromNow.add(const Duration(days: 1)),
              ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Color _getHolidayTypeColor(String type) {
    switch (type) {
      case 'national':
        return Colors.red;
      case 'company':
        return Colors.indigo;
      case 'optional':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getHolidayTypeIcon(String type) {
    switch (type) {
      case 'national':
        return Icons.flag;
      case 'company':
        return Icons.business;
      case 'optional':
        return Icons.star;
      default:
        return Icons.event;
    }
  }

  // Action handlers
  void _handleCheckIn() {
    // Check if today is a holiday
    holidayController.isHoliday(DateTime.now()).then((isHoliday) {
      if (isHoliday) {
        holidayController.getHolidayForDate(DateTime.now()).then((holiday) {
          Get.dialog(
            AlertDialog(
              title: const Text('Holiday Notice'),
              content: Text(
                'Today is ${holiday?.title ?? 'a holiday'}. Are you sure you want to check in?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.back();
                    _performCheckIn();
                  },
                  child: const Text('Check In Anyway'),
                ),
              ],
            ),
          );
        });
      } else {
        _performCheckIn();
      }
    });
  }

  void _performCheckIn() {
    // Implement actual check-in logic
    Get.snackbar('Success', 'Checked in successfully!');
  }

  void _handleCheckOut() {
    // Implement check-out logic
    Get.snackbar('Success', 'Checked out successfully!');
  }

  void _viewTimesheet() {
    // Navigate to timesheet view
    Get.snackbar('Info', 'Timesheet feature coming soon!');
  }

  void _requestLeave() {
    // Navigate to leave request screen
    Get.snackbar('Info', 'Leave request feature coming soon!');
  }
}
