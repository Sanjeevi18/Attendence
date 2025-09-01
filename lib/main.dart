import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/holiday_controller.dart';
import 'controllers/attendance_controller.dart';
import 'controllers/location_controller.dart';
import 'models/user_model.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/admin/admin_dashboard_screen.dart';
import 'views/admin/employee_detail_screen.dart';
import 'views/employee/employee_dashboard_screen.dart';
import 'views/employee/employee_profile_screen.dart';
import 'views/admin/admin_profile_screen.dart';
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
    Get.put(LocationController());

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
        GetPage(name: '/admin-profile', page: () => const AdminProfileScreen()),
        GetPage(
          name: '/employee-detail',
          page: () => EmployeeDetailScreen(employee: Get.arguments as User),
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

      // Get auth controller and wait for auth check to complete
      final authController = Get.find<AuthController>();

      // Wait for auth check to complete by monitoring the loading state
      while (authController.isLoading.value) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (authController.isLoggedIn.value) {
        // Initialize controllers for logged in users
        Get.put(HolidayController());
        Get.put(AttendanceController());

        // Navigate to appropriate dashboard
        final user = authController.currentUser.value;
        if (user != null) {
          if (user.isAdmin) {
            Get.off(() => const AdminDashboardScreen());
          } else {
            Get.off(() => const EmployeeDashboardScreen());
          }
        } else {
          // Edge case: logged in but no user data
          Get.off(() => const LoginScreen());
        }
      } else {
        // Show login screen
        Get.off(() => const LoginScreen());
      }
    } catch (e) {
      print('App initialization error: $e');
      // In case of error, show login screen
      Get.off(() => const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sandy Loading Animation
              Container(
                width: 150,
                height: 150,
                child: Lottie.asset(
                  'assets/Sandy Loading.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              const SizedBox(height: 40),
              // Loading text
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
