import 'package:get/get.dart';
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
        }
      }
    } catch (e) {
      print('Auth state check error: $e');
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
        role: 'employee',
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
      await FirebaseService.signOut();
      await _clearLoginState();

      currentUser.value = null;
      currentCompany.value = null;
      isLoggedIn.value = false;

      Get.offAllNamed('/onboarding');
    } catch (e) {
      Get.snackbar('Error', 'Logout failed: ${e.toString()}');
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

  // Validate if user can access company features
  bool get canAccessCompanyFeatures =>
      currentUser.value != null &&
      currentCompany.value != null &&
      currentUser.value!.isActive &&
      currentCompany.value!.isActive;
}
