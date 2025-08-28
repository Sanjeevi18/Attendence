import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'admin', 'employee'
  final String companyId;
  final String? profileImage;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final String? phone;
  final String? department;
  final String? designation;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.companyId,
    this.profileImage,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.phone,
    this.department,
    this.designation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'companyId': companyId,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'isActive': isActive,
      'phone': phone,
      'department': department,
      'designation': designation,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'employee',
      companyId: map['companyId'] ?? '',
      profileImage: map['profileImage'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] is Timestamp
          ? (map['lastLoginAt'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      phone: map['phone'],
      department: map['department'],
      designation: map['designation'],
    );
  }

  factory User.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return User.fromMap(data);
  }

  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? companyId,
    String? profileImage,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    String? phone,
    String? department,
    String? designation,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      designation: designation ?? this.designation,
    );
  }
}
