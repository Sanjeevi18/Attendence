import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/holiday_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/attendance_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_calendar_widget.dart';
import 'employee_management_screen.dart';
import 'admin_profile_screen.dart';
import 'employee_location_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final HolidayController holidayController = Get.put(HolidayController());
  final AttendanceController attendanceController = Get.put(
    AttendanceController(),
  );
  final AuthController authController = Get.find<AuthController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => Get.to(() => const EmployeeLocationScreen()),
            tooltip: 'Employee Locations',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => holidayController.refreshHolidays(),
          ),
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
                        user?.name.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              onPressed: () => _navigateToProfile(),
            );
          }),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 20), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people, size: 20), text: 'Employees'),
            Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Calendar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildEmployeeManagementTab(),
          _buildCalendarTab(),
        ],
      ),
    );
  }

  // Dashboard Tab
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await attendanceController.refreshStats();
        await holidayController.refreshHolidays();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 16),
            _buildQuickStats(),
            const SizedBox(height: 16),
            _buildRecentActivity(),
            const SizedBox(height: 16),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  // Employee Management Tab
  Widget _buildEmployeeManagementTab() {
    return const EmployeeManagementScreen();
  }

  // Calendar Tab with Holiday Management
  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Company Calendar',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildCalendarSection(),
        ],
      ),
    );
  }

  // Remove Holiday Management Tab
  // Holiday management is now integrated into Calendar tab

  Widget _buildWelcomeCard() {
    return Obx(() {
      final user = authController.currentUser.value;
      final company = authController.currentCompany.value;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back!',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    user?.name ?? 'Admin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    company?.name ?? 'Company',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(
                  Icons.business_center,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildQuickStats() {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Employees',
              '${attendanceController.totalEmployees.value}',
              Icons.people,
              AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Present Today',
              '${attendanceController.presentToday.value}',
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'On Leave',
              '${attendanceController.onLeaveToday.value}',
              Icons.event_busy,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Absent',
              '${attendanceController.absentToday.value}',
              Icons.cancel,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
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
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (attendanceController.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Show message when no recent activity
            return Container(
              padding: const EdgeInsets.all(20),
              child: const Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    'Employee activities will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Add Employee',
                  Icons.person_add,
                  AppTheme.primaryColor,
                  () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Calendar',
                  Icons.calendar_month,
                  Colors.blue,
                  () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'View Reports',
                  Icons.analytics,
                  Colors.green,
                  _viewReports,
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

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Calendar & Holiday Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Click on any date to add a holiday',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          const AdminCalendarWidget(),
        ],
      ),
    );
  }

  // Action handlers
  void _viewReports() {
    Get.snackbar('Info', 'Reports feature coming soon!');
  }

  void _navigateToProfile() {
    Get.to(() => const AdminProfileScreen());
  }
}
