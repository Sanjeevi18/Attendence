import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String id;
  final String name;
  final String email;
  final String? address;
  final String? phone;
  final String? logo;
  final DateTime createdAt;
  final bool isActive;
  final String adminId; // The user ID of the company admin
  final Map<String, dynamic>? settings;
  final String? website;
  final String? description;

  Company({
    required this.id,
    required this.name,
    required this.email,
    this.address,
    this.phone,
    this.logo,
    required this.createdAt,
    this.isActive = true,
    required this.adminId,
    this.settings,
    this.website,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'address': address,
      'phone': phone,
      'logo': logo,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'adminId': adminId,
      'settings': settings,
      'website': website,
      'description': description,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      address: map['address'],
      phone: map['phone'],
      logo: map['logo'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
      adminId: map['adminId'] ?? '',
      settings: map['settings'] != null
          ? Map<String, dynamic>.from(map['settings'])
          : null,
      website: map['website'],
      description: map['description'],
    );
  }

  factory Company.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Company.fromMap(data);
  }

  Company copyWith({
    String? id,
    String? name,
    String? email,
    String? address,
    String? phone,
    String? logo,
    DateTime? createdAt,
    bool? isActive,
    String? adminId,
    Map<String, dynamic>? settings,
    String? website,
    String? description,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      adminId: adminId ?? this.adminId,
      settings: settings ?? this.settings,
      website: website ?? this.website,
      description: description ?? this.description,
    );
  }
}
