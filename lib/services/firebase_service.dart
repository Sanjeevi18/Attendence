import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/holiday_model.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final firebase_auth.FirebaseAuth _auth =
      firebase_auth.FirebaseAuth.instance;

  // Collections
  static const String _usersCollection = 'users';
  static const String _companiesCollection = 'companies';
  static const String _holidaysCollection = 'holidays';
  static const String _attendanceCollection = 'attendance';

  // Authentication Methods
  static Future<firebase_auth.UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to create account: ${e.toString()}');
    }
  }

  static Future<firebase_auth.UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static firebase_auth.User? getCurrentFirebaseUser() {
    return _auth.currentUser;
  }

  // Company Methods
  static Future<String> createCompany(Company company) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(_companiesCollection)
          .add(company.toMap());

      // Update the company with its document ID
      await docRef.update({'id': docRef.id});

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create company: ${e.toString()}');
    }
  }

  static Future<Company?> getCompanyById(String companyId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_companiesCollection)
          .doc(companyId)
          .get();

      if (doc.exists) {
        return Company.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get company: ${e.toString()}');
    }
  }

  static Future<Company?> getCompanyByName(String companyName) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_companiesCollection)
          .where('name', isEqualTo: companyName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Company.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find company: ${e.toString()}');
    }
  }

  // User Methods
  static Future<String> createUser(User user) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(_usersCollection)
          .add(user.toMap());

      // Update the user with its document ID
      await docRef.update({'id': docRef.id});

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  static Future<User?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  static Future<User?> getUserByEmail(String email) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return User.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find user: ${e.toString()}');
    }
  }

  static Future<List<User>> getUsersByCompany(String companyId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      return query.docs.map((doc) => User.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get company users: ${e.toString()}');
    }
  }

  static Future<void> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  static Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'lastLoginAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update last login: ${e.toString()}');
    }
  }

  // Holiday Methods
  static Future<String> createHoliday(Holiday holiday) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(_holidaysCollection)
          .add(holiday.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create holiday: ${e.toString()}');
    }
  }

  static Future<List<Holiday>> getHolidaysByCompany(String companyId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_holidaysCollection)
          .where('companyId', isEqualTo: companyId)
          .orderBy('date', descending: false)
          .get();

      return query.docs.map((doc) => Holiday.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get holidays: ${e.toString()}');
    }
  }

  static Future<List<Holiday>> getHolidaysInDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_holidaysCollection)
          .where('companyId', isEqualTo: companyId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      return query.docs.map((doc) => Holiday.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get holidays in range: ${e.toString()}');
    }
  }

  static Future<void> updateHoliday(String holidayId, Holiday holiday) async {
    try {
      await _firestore
          .collection(_holidaysCollection)
          .doc(holidayId)
          .update(holiday.toMap());
    } catch (e) {
      throw Exception('Failed to update holiday: ${e.toString()}');
    }
  }

  static Future<void> deleteHoliday(String holidayId) async {
    try {
      await _firestore.collection(_holidaysCollection).doc(holidayId).delete();
    } catch (e) {
      throw Exception('Failed to delete holiday: ${e.toString()}');
    }
  }

  // Check if user is admin of company
  static Future<bool> isCompanyAdmin(String userId, String companyId) async {
    try {
      final user = await getUserById(userId);
      if (user == null) return false;

      final company = await getCompanyById(companyId);
      if (company == null) return false;

      return user.isAdmin &&
          user.companyId == companyId &&
          company.adminId == userId;
    } catch (e) {
      return false;
    }
  }

  // Validate user access to company
  static Future<bool> validateUserCompanyAccess(
    String userId,
    String companyId,
  ) async {
    try {
      final user = await getUserById(userId);
      return user != null && user.companyId == companyId && user.isActive;
    } catch (e) {
      return false;
    }
  }
}
