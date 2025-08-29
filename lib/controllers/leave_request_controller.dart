import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/leave_request_model.dart';
import '../controllers/auth_controller.dart';

class LeaveRequestController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();

  // Form fields
  final Rx<LeaveType?> selectedLeaveType = Rx<LeaveType?>(null);
  final Rx<DateTime?> fromDate = Rx<DateTime?>(null);
  final Rx<DateTime?> toDate = Rx<DateTime?>(null);
  final TextEditingController reasonController = TextEditingController();

  final RxList<LeaveRequest> userLeaveRequests = <LeaveRequest>[].obs;
  final RxList<LeaveRequest> pendingLeaveRequests = <LeaveRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserLeaveRequests();
    if (_authController.currentUser.value?.isAdmin == true) {
      loadPendingLeaveRequests();
    }
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }

  Future<void> loadUserLeaveRequests() async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      if (user == null) return;

      // Use a simpler query to avoid index requirements
      final querySnapshot = await _firestore
          .collection('leave_requests')
          .where('userId', isEqualTo: user.id)
          .get();

      // Sort manually by createdAt in memory to avoid index requirement
      final requests =
          querySnapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      userLeaveRequests.value = requests;
    } catch (e) {
      error.value = 'Failed to load leave requests: $e';
      print('Error loading user leave requests: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPendingLeaveRequests() async {
    try {
      final user = _authController.currentUser.value;
      if (user == null || !user.isAdmin) return;

      final querySnapshot = await _firestore
          .collection('leave_requests')
          .where('companyId', isEqualTo: user.companyId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: false)
          .get();

      final requests = querySnapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .toList();

      pendingLeaveRequests.value = requests;
    } catch (e) {
      error.value = 'Failed to load pending requests: $e';
      print('Error loading pending leave requests: $e');
    }
  }

  Future<bool> submitLeaveRequest({
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      if (user == null) {
        error.value = 'User not found';
        return false;
      }

      // Validate dates
      if (fromDate.isAfter(toDate)) {
        error.value = 'From date cannot be after to date';
        return false;
      }

      if (fromDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        error.value = 'Cannot request leave for past dates';
        return false;
      }

      final leaveRequest = LeaveRequest(
        id: '',
        userId: user.id,
        userName: user.name,
        companyId: user.companyId,
        leaveType: leaveType,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('leave_requests').add(leaveRequest.toMap());

      Get.snackbar(
        'Success',
        'Leave request submitted successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadUserLeaveRequests();
      return true;
    } catch (e) {
      error.value = 'Failed to submit leave request: $e';
      Get.snackbar(
        'Error',
        'Failed to submit leave request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> approveLeaveRequest(String requestId, {String? comments}) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      if (user == null || !user.isAdmin) {
        error.value = 'Unauthorized';
        return false;
      }

      await _firestore.collection('leave_requests').doc(requestId).update({
        'status': 'approved',
        'adminComments': comments,
        'reviewedAt': DateTime.now(),
        'reviewedBy': user.name,
      });

      Get.snackbar(
        'Success',
        'Leave request approved',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadPendingLeaveRequests();
      return true;
    } catch (e) {
      error.value = 'Failed to approve request: $e';
      Get.snackbar(
        'Error',
        'Failed to approve request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> rejectLeaveRequest(String requestId, {String? comments}) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      if (user == null || !user.isAdmin) {
        error.value = 'Unauthorized';
        return false;
      }

      await _firestore.collection('leave_requests').doc(requestId).update({
        'status': 'rejected',
        'adminComments': comments,
        'reviewedAt': DateTime.now(),
        'reviewedBy': user.name,
      });

      Get.snackbar(
        'Success',
        'Leave request rejected',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadPendingLeaveRequests();
      return true;
    } catch (e) {
      error.value = 'Failed to reject request: $e';
      Get.snackbar(
        'Error',
        'Failed to reject request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> cancelLeaveRequest(String requestId) async {
    try {
      isLoading.value = true;

      await _firestore.collection('leave_requests').doc(requestId).update({
        'status': 'cancelled',
      });

      Get.snackbar(
        'Success',
        'Leave request cancelled',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadUserLeaveRequests();
      return true;
    } catch (e) {
      error.value = 'Failed to cancel request: $e';
      Get.snackbar(
        'Error',
        'Failed to cancel request: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  // Form helper methods
  void clearForm() {
    selectedLeaveType.value = null;
    fromDate.value = null;
    toDate.value = null;
    reasonController.clear();
  }

  Future<bool> submitFormLeaveRequest() async {
    if (selectedLeaveType.value == null ||
        fromDate.value == null ||
        toDate.value == null ||
        reasonController.text.trim().isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please fill all required fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    final success = await submitLeaveRequest(
      leaveType: selectedLeaveType.value!.displayName,
      fromDate: fromDate.value!,
      toDate: toDate.value!,
      reason: reasonController.text.trim(),
    );

    if (success) {
      clearForm();
    }

    return success;
  }
}
