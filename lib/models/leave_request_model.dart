import 'package:flutter/material.dart';

class LeaveRequest {
  final String id;
  final String userId;
  final String userName;
  final String companyId;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // pending, approved, rejected
  final String? adminComments;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.companyId,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.adminComments,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map, String docId) {
    return LeaveRequest(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      companyId: map['companyId'] ?? '',
      leaveType: map['leaveType'] ?? '',
      fromDate: map['fromDate']?.toDate() ?? DateTime.now(),
      toDate: map['toDate']?.toDate() ?? DateTime.now(),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      adminComments: map['adminComments'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      reviewedAt: map['reviewedAt']?.toDate(),
      reviewedBy: map['reviewedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'companyId': companyId,
      'leaveType': leaveType,
      'fromDate': fromDate,
      'toDate': toDate,
      'reason': reason,
      'status': status,
      'adminComments': adminComments,
      'createdAt': createdAt,
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
    };
  }

  int get totalDays {
    return toDate.difference(fromDate).inDays + 1;
  }
}

enum LeaveType {
  sick('Sick Leave'),
  casual('Casual Leave'),
  annual('Annual Leave'),
  maternity('Maternity Leave'),
  paternity('Paternity Leave'),
  emergency('Emergency Leave'),
  unpaid('Unpaid Leave');

  const LeaveType(this.displayName);
  final String displayName;

  // Get icon for each leave type
  IconData get icon {
    switch (this) {
      case LeaveType.sick:
        return Icons.local_hospital;
      case LeaveType.casual:
        return Icons.beach_access;
      case LeaveType.annual:
        return Icons.calendar_month;
      case LeaveType.maternity:
        return Icons.child_care;
      case LeaveType.paternity:
        return Icons.family_restroom;
      case LeaveType.emergency:
        return Icons.emergency;
      case LeaveType.unpaid:
        return Icons.money_off;
    }
  }

  // Get color for each leave type
  Color get color {
    switch (this) {
      case LeaveType.sick:
        return Colors.red;
      case LeaveType.casual:
        return Colors.blue;
      case LeaveType.annual:
        return Colors.green;
      case LeaveType.maternity:
        return Colors.pink;
      case LeaveType.paternity:
        return Colors.indigo;
      case LeaveType.emergency:
        return Colors.orange;
      case LeaveType.unpaid:
        return Colors.grey;
    }
  }
}
