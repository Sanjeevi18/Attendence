import 'package:get/get.dart';
import '../views/auth/login_screen.dart';
import '../views/admin/admin_dashboard_screen.dart';
import '../views/admin/holiday_management_screen.dart';
import '../views/admin/admin_setup_screen.dart';
import '../views/employee/employee_dashboard_screen.dart';
import '../views/employee/leave_request_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String adminDashboard = '/admin';
  static const String employeeDashboard = '/employee';
  static const String holidayManagement = '/admin/holidays';
  static const String leaveRequest = '/employee/leave-request';
  static const String adminSetup = '/admin/setup';

  static List<GetPage> routes = [
    GetPage(name: login, page: () => const LoginScreen()),
    GetPage(name: adminDashboard, page: () => const AdminDashboardScreen()),
    GetPage(
      name: employeeDashboard,
      page: () => const EmployeeDashboardScreen(),
    ),
    GetPage(
      name: holidayManagement,
      page: () => const HolidayManagementScreen(),
    ),
    GetPage(name: leaveRequest, page: () => const LeaveRequestScreen()),
    GetPage(name: adminSetup, page: () => const AdminSetupScreen()),
  ];
}
