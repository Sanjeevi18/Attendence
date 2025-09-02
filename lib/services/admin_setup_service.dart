import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/snackbar_utils.dart';

class AdminSetupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a new admin user in both Firebase Auth and Firestore
  /// This method should be used when you need to recover or create admin access
  static Future<bool> createAdminUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? department,
    String? designation,
    String? companyId,
    String? companyName,
  }) async {
    try {
      // Step 1: Create user in Firebase Authentication
      print('Creating admin user in Firebase Auth...');
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user in Firebase Auth');
      }

      // Step 2: Create user document in Firestore
      print('Creating admin user document in Firestore...');
      final Map<String, dynamic> userData = {
        'id': user.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'admin', // This is the key field that makes them admin
        'department': department ?? 'Administration',
        'designation': designation ?? 'Administrator',
        'profileImage': null,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Company information
        'companyId': companyId ?? 'default_company',
        'companyName': companyName ?? 'Default Company',
        // Additional admin fields
        'permissions': {
          'canManageEmployees': true,
          'canManageHolidays': true,
          'canViewReports': true,
          'canApproveLeaves': true,
        },
        'lastLogin': null,
        'deviceToken': null,
      };

      // Create user document with the UID as document ID
      await _firestore.collection('users').doc(user.uid).set(userData);

      // Step 3: Create company document if it doesn't exist
      if (companyId != null) {
        print('Creating/updating company document...');
        await _firestore.collection('companies').doc(companyId).set({
          'id': companyId,
          'name': companyName ?? 'Default Company',
          'adminId': user.uid,
          'adminEmail': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));
      }

      print('Admin user created successfully: ${user.uid}');
      SnackbarUtils.showSuccess(
        'Admin user "$name" created successfully!\nEmail: $email',
        title: 'Admin Created',
      );

      return true;
    } catch (e) {
      print('Error creating admin user: $e');
      SnackbarUtils.showError(
        'Failed to create admin user: ${e.toString()}',
        title: 'Creation Failed',
      );
      return false;
    }
  }

  /// Quick method to create a default admin user
  /// Use this in emergency situations when you lose admin access
  static Future<bool> createDefaultAdmin() async {
    return await createAdminUser(
      email: 'admin@company.com',
      password: 'Admin123!',
      name: 'System Administrator',
      phone: '+1234567890',
      department: 'Administration',
      designation: 'System Administrator',
      companyId: 'default_company',
      companyName: 'Default Company',
    );
  }

  /// Method to promote an existing user to admin
  static Future<bool> promoteUserToAdmin(String userId) async {
    try {
      print('Promoting user to admin: $userId');

      // Update user document to admin role
      await _firestore.collection('users').doc(userId).update({
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
        'permissions': {
          'canManageEmployees': true,
          'canManageHolidays': true,
          'canViewReports': true,
          'canApproveLeaves': true,
        },
      });

      print('User promoted to admin successfully');
      SnackbarUtils.showSuccess(
        'User has been promoted to admin successfully!',
        title: 'Promotion Complete',
      );

      return true;
    } catch (e) {
      print('Error promoting user to admin: $e');
      SnackbarUtils.showError(
        'Failed to promote user: ${e.toString()}',
        title: 'Promotion Failed',
      );
      return false;
    }
  }

  /// Method to check if any admin exists in the system
  static Future<bool> hasAdminUser() async {
    try {
      final QuerySnapshot adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return adminQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for admin users: $e');
      return false;
    }
  }

  /// Method to list all admin users
  static Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final QuerySnapshot adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();

      return adminQuery.docs
          .map(
            (doc) => {...doc.data() as Map<String, dynamic>, 'docId': doc.id},
          )
          .toList();
    } catch (e) {
      print('Error getting admin users: $e');
      return [];
    }
  }
}
