import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../services/firebase_service.dart';

class AuthController extends GetxController {
  // Observable variables
  final Rx<User?> currentUser = Rx<User?>(null);
  final Rx<Company?> currentCompany = Rx<Company?>(null);
  final RxBool isLoggedIn = false.obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _checkAuthState();
  }

  // Check if user is already logged in
  Future<void> _checkAuthState() async {
    try {
      isLoading.value = true;

      // First check SharedPreferences for login state
      final prefs = await SharedPreferences.getInstance();
      final isLoggedInPref = prefs.getBool('isLoggedIn') ?? false;
      final savedUserId = prefs.getString('userId');
      final savedUserEmail = prefs.getString('userEmail');

      if (isLoggedInPref && savedUserId != null && savedUserEmail != null) {
        // Check if Firebase user is still authenticated
        final firebaseUser = FirebaseService.getCurrentFirebaseUser();

        if (firebaseUser != null && firebaseUser.email == savedUserEmail) {
          // Get user data from Firestore
          final user = await FirebaseService.getUserByEmail(
            firebaseUser.email!,
          );
          if (user != null && user.isActive && user.id == savedUserId) {
            currentUser.value = user;
            isLoggedIn.value = true;

            // Load company data
            final company = await FirebaseService.getCompanyById(
              user.companyId,
            );
            currentCompany.value = company;

            // Update last login
            await FirebaseService.updateLastLogin(user.id);

            print('Auto-login successful for: ${user.email}');
            return;
          }
        }
      }

      // If SharedPreferences check failed, try Firebase Auth only
      final firebaseUser = FirebaseService.getCurrentFirebaseUser();
      if (firebaseUser != null) {
        // Get user data from Firestore
        final user = await FirebaseService.getUserByEmail(firebaseUser.email!);
        if (user != null && user.isActive) {
          currentUser.value = user;
          isLoggedIn.value = true;

          // Load company data
          final company = await FirebaseService.getCompanyById(user.companyId);
          currentCompany.value = company;

          // Update last login
          await FirebaseService.updateLastLogin(user.id);

          // Save login state for next time
          await _saveLoginState();

          print('Firebase auto-login successful for: ${user.email}');
          return;
        }
      }

      // If no valid login found, clear any stale data
      await _clearLoginState();
      print('No valid login state found');
    } catch (e) {
      print('Auth state check error: $e');
      // Clear potentially corrupted login state
      await _clearLoginState();
    } finally {
      isLoading.value = false;
    }
  }

  // Register new company admin
  Future<bool> registerCompanyAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
    String? companyAddress,
    String? companyPhone,
  }) async {
    try {
      isLoading.value = true;
      error.value = '';

      // Check if company already exists
      final existingCompany = await FirebaseService.getCompanyByName(
        companyName,
      );
      if (existingCompany != null) {
        throw Exception('A company with this name already exists');
      }

      // Create Firebase Auth user
      final credential = await FirebaseService.signUpWithEmailPassword(
        email,
        password,
      );
      if (credential?.user == null) {
        throw Exception('Failed to create authentication account');
      }

      final firebaseUserId = credential!.user!.uid;

      // Create company document
      final company = Company(
        id: '', // Will be set by Firestore
        name: companyName,
        email: email,
        address: companyAddress,
        phone: companyPhone,
        createdAt: DateTime.now(),
        adminId: firebaseUserId,
      );

      final companyId = await FirebaseService.createCompany(company);

      // Create admin user document
      final user = User(
        id: firebaseUserId,
        email: email,
        name: name,
        role: 'admin',
        companyId: companyId,
        createdAt: DateTime.now(),
      );

      await FirebaseService.createUser(user);

      // Set current user and company
      currentUser.value = user;
      currentCompany.value = company.copyWith(id: companyId);
      isLoggedIn.value = true;

      // Save login state
      await _saveLoginState();

      Get.snackbar('Success', 'Company registered successfully!');
      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', 'Registration failed: ${e.toString()}');

      // Clean up Firebase Auth user if company creation failed
      final firebaseUser = FirebaseService.getCurrentFirebaseUser();
      if (firebaseUser != null) {
        await firebaseUser.delete();
      }

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Create employee (Admin only)
  Future<bool> createEmployee({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? department,
    String? designation,
    String role = 'employee',
  }) async {
    try {
      isLoading.value = true;
      error.value = '';

      // Check if current user is admin
      if (currentUser.value == null || !currentUser.value!.isAdmin) {
        throw Exception('Only administrators can create employees');
      }

      // Check if user already exists
      final existingUser = await FirebaseService.getUserByEmail(email);
      if (existingUser != null) {
        throw Exception('User with this email already exists');
      }

      // Create Firebase Auth user
      final credential = await FirebaseService.signUpWithEmailPassword(
        email,
        password,
      );
      if (credential?.user == null) {
        throw Exception('Failed to create authentication account');
      }

      final firebaseUserId = credential!.user!.uid;

      // Create employee user document
      final employee = User(
        id: firebaseUserId,
        email: email,
        name: name,
        role: role,
        companyId: currentUser.value!.companyId,
        phone: phone,
        department: department,
        designation: designation,
        createdAt: DateTime.now(),
      );

      await FirebaseService.createUser(employee);

      Get.snackbar('Success', 'Employee "$name" created successfully!');
      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', 'Failed to create employee: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Login method
  Future<bool> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';

      // Sign in with Firebase Auth
      final credential = await FirebaseService.signInWithEmailPassword(
        email,
        password,
      );
      if (credential?.user == null) {
        throw Exception('Invalid email or password');
      }

      // Get user data from Firestore
      final user = await FirebaseService.getUserByEmail(email);
      if (user == null) {
        throw Exception('User data not found');
      }

      if (!user.isActive) {
        throw Exception(
          'Your account has been deactivated. Please contact your administrator.',
        );
      }

      // Load company data
      final company = await FirebaseService.getCompanyById(user.companyId);
      if (company == null) {
        throw Exception('Company not found');
      }

      if (!company.isActive) {
        throw Exception('Your company account has been deactivated');
      }

      // Set current user and company
      currentUser.value = user;
      currentCompany.value = company;
      isLoggedIn.value = true;

      // Update last login
      await FirebaseService.updateLastLogin(user.id);

      // Save login state
      await _saveLoginState();

      Get.snackbar('Success', 'Welcome back, ${user.name}!');
      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', 'Login failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Demo login method
  Future<bool> loginWithDemo(String role) async {
    try {
      isLoading.value = true;

      // For demo purposes, create a mock user
      final mockCompany = Company(
        id: 'demo-company',
        name: 'Demo Company',
        email: 'admin@demo.com',
        createdAt: DateTime.now(),
        adminId: 'demo-admin',
      );

      final mockUser = User(
        id: role == 'admin' ? 'demo-admin' : 'demo-employee',
        email: role == 'admin' ? 'admin@demo.com' : 'employee@demo.com',
        name: role == 'admin' ? 'Demo Admin' : 'Demo Employee',
        role: role,
        companyId: 'demo-company',
        createdAt: DateTime.now(),
      );

      currentUser.value = mockUser;
      currentCompany.value = mockCompany;
      isLoggedIn.value = true;

      Get.snackbar('Success', 'Logged in as ${mockUser.name}');
      return true;
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', 'Demo login failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      isLoading.value = true;

      // Sign out from Firebase
      await FirebaseService.signOut();

      // Clear login state from shared preferences
      await _clearLoginState();

      // Clear user data
      currentUser.value = null;
      currentCompany.value = null;
      isLoggedIn.value = false;
      error.value = '';

      // Clear other controllers to prevent memory leaks
      try {
        // Clear all GetX controllers except AuthController
        Get.deleteAll(force: true);
        // Re-register AuthController since we still need it
        Get.put(this, permanent: true);
      } catch (e) {
        print('Error clearing controllers: $e');
      }

      // Navigate to login screen
      Get.offAllNamed('/login');

      Get.snackbar(
        'Success',
        'Logged out successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Logout error: $e');
      Get.snackbar('Error', 'Logout failed: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // Save login state to shared preferences
  Future<void> _saveLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (currentUser.value != null) {
        await prefs.setString('userId', currentUser.value!.id);
        await prefs.setString('userEmail', currentUser.value!.email);
      }
    } catch (e) {
      print('Failed to save login state: $e');
    }
  }

  // Clear login state from shared preferences
  Future<void> _clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('userEmail');
    } catch (e) {
      print('Failed to clear login state: $e');
    }
  }

  // Check if current user is admin
  bool get isAdmin => currentUser.value?.isAdmin ?? false;

  // Check if current user is employee
  bool get isEmployee => currentUser.value?.isEmployee ?? false;

  // Get current company ID
  String? get currentCompanyId => currentUser.value?.companyId;

  // Get current company name
  String? get currentCompanyName => currentCompany.value?.name;

  // Manually refresh auth state (useful for testing or forced refresh)
  Future<void> refreshAuthState() async {
    await _checkAuthState();
  }

  // Check if user session is still valid
  Future<bool> isSessionValid() async {
    try {
      final firebaseUser = FirebaseService.getCurrentFirebaseUser();
      if (firebaseUser == null) return false;

      final user = await FirebaseService.getUserByEmail(firebaseUser.email!);
      return user != null && user.isActive;
    } catch (e) {
      print('Session validation error: $e');
      return false;
    }
  }

  // Validate if user can access company features
  bool get canAccessCompanyFeatures =>
      currentUser.value != null &&
      currentCompany.value != null &&
      currentUser.value!.isActive &&
      currentCompany.value!.isActive;
}
