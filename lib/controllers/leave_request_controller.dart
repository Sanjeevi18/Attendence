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

  // Filter for recent leave requests
  final RxString selectedStatusFilter =
      'all'.obs; // all, pending, approved, rejected

  // Get all leave types except Work From Home for reason dropdown
  List<LeaveType> get leaveTypesForReasons =>
      LeaveType.values.where((type) => type != LeaveType.workFromHome).toList();

  // Get predefined reasons based on leave type
  List<String> getLeaveReasons(LeaveType leaveType) {
    switch (leaveType) {
      case LeaveType.sick:
        return [
          'Fever and flu symptoms',
          'Doctor appointment',
          'Medical treatment',
          'Recovery from illness',
          'Health checkup',
          'Other medical reasons',
        ];
      case LeaveType.casual:
        return [
          'Personal work',
          'Family function',
          'Rest and relaxation',
          'Personal commitment',
          'Other personal reasons',
        ];
      case LeaveType.annual:
        return [
          'Vacation with family',
          'Holiday trip',
          'Annual break',
          'Personal time off',
          'Other vacation reasons',
        ];
      case LeaveType.maternity:
        return [
          'Maternity leave - delivery',
          'Prenatal care',
          'Postnatal care',
          'Baby care',
          'Medical complications',
        ];
      case LeaveType.paternity:
        return [
          'Paternity leave - new born',
          'Supporting spouse',
          'Baby care assistance',
          'Family support',
        ];
      case LeaveType.emergency:
        return [
          'Family emergency',
          'Medical emergency',
          'Urgent personal matter',
          'Unexpected situation',
          'Other emergency',
        ];
      case LeaveType.personal:
        return [
          'Personal development',
          'Family matters',
          'Personal commitments',
          'Self care',
          'Other personal needs',
        ];
      case LeaveType.bereavement:
        return [
          'Death in immediate family',
          'Death of relative',
          'Funeral attendance',
          'Mourning period',
          'Family support during loss',
        ];
      case LeaveType.medical:
        return [
          'Surgery',
          'Medical procedure',
          'Extended medical treatment',
          'Recovery period',
          'Specialist consultation',
        ];
      case LeaveType.study:
        return [
          'Examination',
          'Course attendance',
          'Educational program',
          'Training session',
          'Academic commitment',
        ];
      case LeaveType.compensatory:
        return [
          'Overtime compensation',
          'Weekend work compensation',
          'Holiday work compensation',
          'Extra hours worked',
        ];
      case LeaveType.unpaid:
        return [
          'Extended personal leave',
          'Financial constraints',
          'Personal sabbatical',
          'Family care',
          'Other unpaid leave reasons',
        ];
      default:
        return ['Other'];
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize with no loading state
    isLoading.value = false;
    error.value = '';

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

  void resetLoadingState() {
    isLoading.value = false;
    error.value = '';
  }

  Future<void> loadUserLeaveRequests() async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      if (user == null) {
        error.value = 'User not found';
        return;
      }

      // Use a simpler query to avoid index requirements
      final querySnapshot = await _firestore
          .collection('leave_requests')
          .where('userId', isEqualTo: user.id)
          .get();

      // Filter out cancelled/deleted requests and apply status filter
      final allRequests = querySnapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .where(
            (request) =>
                request.status != 'cancelled' && request.status != 'deleted',
          )
          .toList();

      // Apply status filter
      List<LeaveRequest> filteredRequests;
      if (selectedStatusFilter.value == 'all') {
        filteredRequests = allRequests;
      } else {
        filteredRequests = allRequests
            .where((request) => request.status == selectedStatusFilter.value)
            .toList();
      }

      // Sort manually by createdAt in memory to avoid index requirement
      filteredRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      userLeaveRequests.value = filteredRequests;
      error.value = ''; // Clear any previous errors
    } catch (e) {
      error.value = 'Failed to load leave requests: $e';
      print('Error loading user leave requests: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Method to update status filter and reload data
  void updateStatusFilter(String status) {
    selectedStatusFilter.value = status;
    loadUserLeaveRequests();
  }

  // Get filtered leave requests count for each status
  Map<String, int> getLeaveRequestCounts() {
    final counts = <String, int>{
      'all': 0,
      'pending': 0,
      'approved': 0,
      'rejected': 0,
    };

    for (final request in userLeaveRequests) {
      counts['all'] = counts['all']! + 1;
      counts[request.status] = (counts[request.status] ?? 0) + 1;
    }

    return counts;
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

  Future<bool> deleteLeaveRequest(String requestId) async {
    try {
      isLoading.value = true;

      await _firestore.collection('leave_requests').doc(requestId).delete();

      Get.snackbar(
        'Success',
        'Leave request deleted',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadUserLeaveRequests();
      return true;
    } catch (e) {
      error.value = 'Failed to delete request: $e';
      Get.snackbar(
        'Error',
        'Failed to delete request: $e',
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
