import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../controllers/auth_controller.dart';
import '../../controllers/attendance_controller.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final AuthController authController = Get.find<AuthController>();
  final AttendanceController attendanceController =
      Get.find<AttendanceController>();
  List<User> employees = [];
  Map<String, bool> employeeDutyStatus = {};
  Map<String, Map<String, dynamic>?> employeeLocationData = {};
  bool isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    // Set up periodic refresh every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadEmployeeDutyStatus();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      setState(() => isLoading = true);

      final companyId = authController.currentCompanyId;
      if (companyId != null) {
        final users = await FirebaseService.getUsersByCompany(companyId);

        // Remove duplicates by using a Map with userId as key
        final Map<String, User> uniqueUsers = {};
        for (final user in users) {
          uniqueUsers[user.id] = user;
        }

        setState(() {
          // Convert back to list and show both employees and admins
          employees = uniqueUsers.values.toList();
        });

        // Load real-time duty status for all employees
        await _loadEmployeeDutyStatus();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load employees: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadEmployeeDutyStatus() async {
    if (employees.isEmpty) return;

    try {
      // Update attendance controller's employee list
      attendanceController.allEmployees.value = employees;

      // Get real-time duty status and location data for all employees
      final dutyStatus = await attendanceController.getAllEmployeesDutyStatus();
      final Map<String, Map<String, dynamic>?> locationData = {};

      // Load location data in parallel for better performance
      final locationFutures = employees.map((employee) async {
        final data = await attendanceController.getEmployeeLocationData(
          employee.id,
        );
        return MapEntry(employee.id, data);
      });

      final locationResults = await Future.wait(locationFutures);
      for (final entry in locationResults) {
        locationData[entry.key] = entry.value;
      }

      if (mounted) {
        setState(() {
          employeeDutyStatus = dutyStatus;
          employeeLocationData = locationData;
        });
      }
    } catch (e) {
      print('Error loading duty status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmployees,
        child: Column(
          children: [
            _buildStatsCard(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildEmployeesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEmployeeDialog,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Employee',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final activeCount = employeeDutyStatus.values
        .where((isActive) => isActive)
        .length;
    final inactiveCount = employees.length - activeCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Users',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${employees.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${employees.where((e) => e.role == 'employee').length} Employees • ${employees.where((e) => e.role == 'admin').length} Admins',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount Active • $inactiveCount Inactive',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              authController.currentCompanyName ?? 'Company',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesList() {
    if (employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first employee to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return _buildEmployeeCard(employee);
      },
    );
  }

  Widget _buildEmployeeCard(User employee) {
    final isOnDuty = employeeDutyStatus[employee.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEmployeeDetails(employee),
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: employee.role == 'admin'
                ? Colors.red
                : Colors.indigo,
            radius: 25,
            child: Text(
              employee.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  employee.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: employee.role == 'admin'
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: employee.role == 'admin' ? Colors.red : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Text(
                  employee.role.toUpperCase(),
                  style: TextStyle(
                    color: employee.role == 'admin' ? Colors.red : Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                employee.email,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnDuty ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnDuty ? 'On Duty' : 'Off Duty',
                    style: TextStyle(
                      color: isOnDuty ? Colors.green : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isOnDuty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (employee.department != null ||
                  employee.designation != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (employee.department != null) ...[
                      Icon(Icons.business, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        employee.department!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                    if (employee.department != null &&
                        employee.designation != null)
                      Text(
                        ' • ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    if (employee.designation != null) ...[
                      Icon(Icons.work, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        employee.designation!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
              // Location info
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getLocationText(employee.id),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnDuty ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              // Remove button
              InkWell(
                onTap: () => _confirmRemoveEmployee(employee),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLocationText(String employeeId) {
    final locationData = employeeLocationData[employeeId];
    if (locationData == null) {
      return 'Location not available';
    }

    final isActive = locationData['isActive'] ?? false;
    final location = locationData['location'] ?? 'Unknown location';

    if (isActive) {
      return 'Current: $location';
    } else {
      return 'Last: $location';
    }
  }

  void _confirmRemoveEmployee(User employee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Employee'),
          content: Text(
            'Are you sure you want to remove ${employee.name}? This action cannot be undone and will delete all associated data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeEmployee(employee);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeEmployee(User employee) async {
    try {
      await attendanceController.removeEmployee(employee.id);
      await _loadEmployees(); // Refresh the list
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove employee: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _navigateToEmployeeDetails(User employee) {
    // Navigate to employee detail screen
    Get.toNamed('/employee-detail', arguments: employee);
  }

  void _showCreateEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isConfirmPasswordVisible = false;
    String selectedRole = 'employee'; // Default role

    final authController = Get.find<AuthController>();
    final companyName = authController.currentCompany.value?.name ?? 'Company';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_add,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Employee',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                'Create account for $companyName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Company Name Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Company: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            companyName,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name Field
                    _buildModernTextField(
                      controller: nameController,
                      label: 'Full Name',
                      hint: 'Enter employee full name',
                      icon: Icons.person_outline,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Email Field
                    _buildModernTextField(
                      controller: emailController,
                      label: 'Email Address',
                      hint: 'Enter employee email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!GetUtils.isEmail(value.trim())) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Role Selection
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Role Selection',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  'Employee',
                                  'Standard user with basic access',
                                  Icons.person,
                                  Colors.blue,
                                  selectedRole == 'employee',
                                  () =>
                                      setState(() => selectedRole = 'employee'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRoleCard(
                                  'Admin',
                                  'Full access with management rights',
                                  Icons.admin_panel_settings,
                                  Colors.red,
                                  selectedRole == 'admin',
                                  () => setState(() => selectedRole = 'admin'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    _buildModernTextField(
                      controller: passwordController,
                      label: 'Password',
                      hint: 'Create a secure password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isPasswordVisible: isPasswordVisible,
                      isRequired: true,
                      onPasswordToggle: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password Field
                    _buildModernTextField(
                      controller: confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Re-enter password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isPasswordVisible: isConfirmPasswordVisible,
                      isRequired: true,
                      onPasswordToggle: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm password';
                        }
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => _createEmployeeFromForm(
                              formKey,
                              nameController,
                              emailController,
                              passwordController,
                              selectedRole,
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_add, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Register Employee',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    String title,
    String description,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color.withOpacity(0.8) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isRequired = false,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onPasswordToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && !isPasswordVisible,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(
              icon,
              color: AppTheme.primaryColor.withOpacity(0.7),
              size: 20,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    onPressed: onPasswordToggle,
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _createEmployeeFromForm(
    GlobalKey<FormState> formKey,
    TextEditingController nameController,
    TextEditingController emailController,
    TextEditingController passwordController,
    String role,
  ) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    try {
      // Show loading
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final success = await authController.createEmployee(
        name: name,
        email: email,
        password: password,
        role: role,
      );

      // Close loading dialog
      Get.back();

      if (success) {
        // Clear input fields
        nameController.clear();
        emailController.clear();
        passwordController.clear();

        // Close create dialog
        Navigator.of(context).pop();
        // Reload employees list
        _loadEmployees();

        // Show success message
        Get.snackbar(
          'Success',
          'Employee $name has been created successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to create employee: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 4),
      );
    }
  }
}
