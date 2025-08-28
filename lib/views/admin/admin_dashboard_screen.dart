import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/holiday_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/shared_calendar_widget.dart';
import 'holiday_management_screen.dart';
import 'employee_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final HolidayController holidayController = Get.put(HolidayController());
  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => holidayController.refreshHolidays(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                authController.logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
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
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildHolidayOverview(),
            const SizedBox(height: 16),
            _buildCalendarSection(),
            const SizedBox(height: 16),
            _buildHolidayStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Obx(() {
      final user = authController.currentUser.value;
      final company = authController.currentCompany.value;
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
                user?.name.substring(0, 1).toUpperCase() ?? 'A',
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
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    user?.name ?? 'Administrator',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    company?.name ?? 'Company',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
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
            const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ],
        ),
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
                  'Manage Holidays',
                  Icons.event,
                  Colors.red,
                  () => Get.to(() => const HolidayManagementScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Employee Management',
                  Icons.people,
                  Colors.blue,
                  () => Get.to(() => const EmployeeManagementScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Attendance Reports',
                  Icons.analytics,
                  Colors.green,
                  () => _viewReports(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Leave Requests',
                  Icons.request_quote,
                  Colors.orange,
                  () => _reviewLeaveRequests(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
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

  Widget _buildHolidayOverview() {
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
                'Holiday Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Get.to(() => const HolidayManagementScreen()),
                child: const Text('Manage All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (holidayController.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = _calculateHolidayStats();
            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Holidays',
                    stats['total'].toString(),
                    Icons.event,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'This Month',
                    stats['thisMonth'].toString(),
                    Icons.calendar_month,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Upcoming',
                    stats['upcoming'].toString(),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Company Holiday Calendar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Get.to(() => const HolidayManagementScreen()),
              icon: const Icon(Icons.settings),
              label: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'All declared holidays will be visible to employees across the organization',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        SharedCalendarWidget(
          showHolidayDetails: true,
          readOnly: false,
          onDateSelected: (date) {
            // Optionally handle date selection
          },
        ),
      ],
    );
  }

  Widget _buildHolidayStatistics() {
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
            'Holiday Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final holidaysByType = _getHolidaysByType();
            return Column(
              children: [
                _buildHolidayTypeRow(
                  'National Holidays',
                  holidaysByType['national'] ?? 0,
                  Colors.red,
                  Icons.flag,
                ),
                const SizedBox(height: 8),
                _buildHolidayTypeRow(
                  'Company Holidays',
                  holidaysByType['company'] ?? 0,
                  Colors.indigo,
                  Icons.business,
                ),
                const SizedBox(height: 8),
                _buildHolidayTypeRow(
                  'Optional Holidays',
                  holidaysByType['optional'] ?? 0,
                  Colors.orange,
                  Icons.star,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHolidayTypeRow(String type, int count, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            type,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, int> _calculateHolidayStats() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final holidays = holidayController.holidays;
    
    return {
      'total': holidays.length,
      'thisMonth': holidays.where((h) => 
        h.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
        h.date.isBefore(endOfMonth.add(const Duration(days: 1)))).length,
      'upcoming': holidays.where((h) => h.date.isAfter(now)).length,
    };
  }

  Map<String, int> _getHolidaysByType() {
    final holidays = holidayController.holidays;
    final Map<String, int> typeCount = {};
    
    for (final holiday in holidays) {
      typeCount[holiday.type] = (typeCount[holiday.type] ?? 0) + 1;
    }
    
    return typeCount;
  }

  // Action handlers
  void _viewReports() {
    Get.snackbar('Info', 'Reports feature coming soon!');
  }

  void _reviewLeaveRequests() {
    Get.snackbar('Info', 'Leave request review feature coming soon!');
  }
}
