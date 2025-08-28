import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/holiday_controller.dart';
import 'controllers/attendance_controller.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/admin/admin_dashboard_screen.dart';
import 'views/employee/employee_dashboard_screen.dart';
import 'views/employee/employee_profile_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LightsAttendanceApp());
}

class LightsAttendanceApp extends StatelessWidget {
  const LightsAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controllers
    Get.put(AuthController());

    return GetMaterialApp(
      title: 'Lights Attendance Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AppInitializer(),
      getPages: [
        GetPage(name: '/onboarding', page: () => const OnboardingScreen()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/admin', page: () => const AdminDashboardScreen()),
        GetPage(name: '/employee', page: () => const EmployeeDashboardScreen()),
        GetPage(
          name: '/employee-profile',
          page: () => const EmployeeProfileScreen(),
        ),
      ],
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if it's first time opening the app
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('isFirstTime') ?? true;

      if (isFirstTime) {
        // Mark as not first time
        await prefs.setBool('isFirstTime', false);
        // Show onboarding
        Get.off(() => const OnboardingScreen());
        return;
      }

      // Check authentication state
      final authController = Get.find<AuthController>();

      // Wait a moment for auth check
      await Future.delayed(const Duration(seconds: 1));

      if (authController.isLoggedIn.value) {
        // Initialize holiday controller for logged in users
        Get.put(HolidayController());

        // Navigate to appropriate dashboard
        final user = authController.currentUser.value;
        if (user != null) {
          if (user.isAdmin) {
            Get.off(() => const AdminDashboardScreen());
          } else {
            Get.off(() => const EmployeeDashboardScreen());
          }
        }
      } else {
        // Show login screen
        Get.off(() => const LoginScreen());
      }
    } catch (e) {
      // In case of error, show login screen
      Get.off(() => const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Icon(Icons.business_center, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Lights Attendance',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Management System',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              SizedBox(height: 20),
              Text(
                'Initializing...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
