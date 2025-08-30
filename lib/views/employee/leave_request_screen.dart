import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/leave_request_controller.dart';
import '../../models/leave_request_model.dart';
import '../../theme/app_theme.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final LeaveRequestController controller = Get.find<LeaveRequestController>();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                strokeWidth: 3,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeaveTypeSection(),
                const SizedBox(height: 20),
                _buildDateSection(),
                const SizedBox(height: 20),
                _buildReasonSection(),
                const SizedBox(height: 30),
                _buildSubmitButton(),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLeaveTypeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => DropdownButtonFormField<LeaveType>(
                value: controller.selectedLeaveType.value,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                hint: const Text('Select leave type'),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a leave type';
                  }
                  return null;
                },
                items: controller.leaveTypesForReasons.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.icon, color: type.color, size: 20),
                        const SizedBox(width: 8),
                        Text(type.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  controller.selectedLeaveType.value = value;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Duration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => InkWell(
                      onTap: () => _selectFromDate(),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'From Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          controller.fromDate.value != null
                              ? DateFormat(
                                  'MMM dd, yyyy',
                                ).format(controller.fromDate.value!)
                              : 'Select date',
                          style: TextStyle(
                            color: controller.fromDate.value != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(
                    () => InkWell(
                      onTap: () => _selectToDate(),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'To Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          controller.toDate.value != null
                              ? DateFormat(
                                  'MMM dd, yyyy',
                                ).format(controller.toDate.value!)
                              : 'Select date',
                          style: TextStyle(
                            color: controller.toDate.value != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Obx(() {
              if (controller.fromDate.value != null &&
                  controller.toDate.value != null) {
                final days =
                    controller.toDate.value!
                        .difference(controller.fromDate.value!)
                        .inDays +
                    1;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Total days: $days',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final selectedType = controller.selectedLeaveType.value;
              if (selectedType != null &&
                  selectedType != LeaveType.workFromHome) {
                final reasons = controller.getLeaveReasons(selectedType);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select reason',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: reasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          controller.reasonController.text = value;
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Or provide custom reason:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            TextFormField(
              controller: controller.reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Please provide a reason for your leave...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason for your leave';
                }
                if (value.trim().length < 10) {
                  return 'Please provide a more detailed reason (at least 10 characters)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitLeaveRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Submit Leave Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _selectFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.fromDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.fromDate.value = picked;
      // Reset to date if it's before from date
      if (controller.toDate.value != null &&
          controller.toDate.value!.isBefore(picked)) {
        controller.toDate.value = null;
      }
    }
  }

  Future<void> _selectToDate() async {
    if (controller.fromDate.value == null) {
      Get.snackbar(
        'Error',
        'Please select from date first',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.toDate.value ?? controller.fromDate.value!,
      firstDate: controller.fromDate.value!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.toDate.value = picked;
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (controller.selectedLeaveType.value == null) {
      Get.snackbar(
        'Error',
        'Please select a leave type',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (controller.fromDate.value == null || controller.toDate.value == null) {
      Get.snackbar(
        'Error',
        'Please select both from and to dates',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final success = await controller.submitLeaveRequest(
      leaveType: controller.selectedLeaveType.value!.name,
      fromDate: controller.fromDate.value!,
      toDate: controller.toDate.value!,
      reason: controller.reasonController.text.trim(),
    );

    if (success) {
      // Reset form
      controller.selectedLeaveType.value = null;
      controller.fromDate.value = null;
      controller.toDate.value = null;
      controller.reasonController.clear();

      Get.back(); // Go back to previous screen
    }
  }
}
