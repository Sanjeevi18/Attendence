import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/holiday_controller.dart';
import 'controllers/attendance_controller.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF000000), // Pure black
              Color(0xFF1a1a1a), // Dark gray
              Color(0xFF2d2d2d), // Medium gray
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Modern Loading Animation Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Rotating border
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                    // Center icon
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              // App Title with modern typography
              const Text(
                'Lights Attendance',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 2.0,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Management System',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w200,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 60),
              // Modern loading indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Initializing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Minimalist dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(true),
                  const SizedBox(width: 8),
                  _buildDot(false),
                  const SizedBox(width: 8),
                  _buildDot(false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: active ? 12 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
