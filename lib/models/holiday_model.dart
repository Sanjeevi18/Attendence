import 'package:cloud_firestore/cloud_firestore.dart';

class Holiday {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final DateTime date;
  final String type; // 'national', 'company', 'optional'
  final bool isRecurring;
  final DateTime createdAt;
  final String createdBy;

  Holiday({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.isRecurring = false,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'type': type,
      'isRecurring': isRecurring,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory Holiday.fromMap(Map<String, dynamic> map) {
    return Holiday(
      id: map['id'] ?? '',
      companyId: map['companyId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      type: map['type'] ?? 'company',
      isRecurring: map['isRecurring'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  factory Holiday.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Holiday.fromMap(data);
  }

  Holiday copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    DateTime? date,
    String? type,
    bool? isRecurring,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Holiday(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'Holiday{id: $id, title: $title, date: $date, type: $type}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Holiday && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
