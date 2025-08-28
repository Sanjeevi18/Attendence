class Attendance {
  final String id;
  final String userId;
  final String companyId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? checkInLocation;
  final String? checkOutLocation;
  final double? totalHours;
  final String status; // 'present', 'late', 'absent', 'holiday'
  final String? notes;
  final DateTime date;

  Attendance({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.totalHours,
    required this.status,
    this.notes,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'companyId': companyId,
      'checkInTime': checkInTime.millisecondsSinceEpoch,
      'checkOutTime': checkOutTime?.millisecondsSinceEpoch,
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'totalHours': totalHours,
      'status': status,
      'notes': notes,
      'date': date.millisecondsSinceEpoch,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      companyId: map['companyId'] ?? '',
      checkInTime: DateTime.fromMillisecondsSinceEpoch(map['checkInTime']),
      checkOutTime: map['checkOutTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['checkOutTime'])
          : null,
      checkInLocation: map['checkInLocation'],
      checkOutLocation: map['checkOutLocation'],
      totalHours: map['totalHours']?.toDouble(),
      status: map['status'] ?? 'present',
      notes: map['notes'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
    );
  }

  bool get isCheckedOut => checkOutTime != null;

  double get calculatedHours {
    if (checkOutTime == null) return 0.0;
    return checkOutTime!.difference(checkInTime).inMinutes / 60.0;
  }
}
