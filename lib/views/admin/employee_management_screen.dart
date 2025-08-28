import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final AuthController authController = Get.find<AuthController>();
  List<User> employees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      setState(() => isLoading = true);

      final companyId = authController.currentCompanyId;
      if (companyId != null) {
        final users = await FirebaseService.getUsersByCompany(companyId);
        setState(() {
          employees = users.where((user) => user.role == 'employee').toList();
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load employees: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCard(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildEmployeesList(),
          ),
        ],
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
                  'Total Employees',
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
              'No employees found',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
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
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              employee.email,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (employee.department != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    employee.department!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
            if (employee.designation != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.work, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    employee.designation!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleEmployeeAction(value, employee),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: employee.isActive ? 'deactivate' : 'activate',
              child: Row(
                children: [
                  Icon(
                    employee.isActive ? Icons.block : Icons.check_circle,
                    size: 20,
                    color: employee.isActive ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    employee.isActive ? 'Deactivate' : 'Activate',
                    style: TextStyle(
                      color: employee.isActive ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEmployeeAction(String action, User employee) {
    switch (action) {
      case 'view':
        _showEmployeeDetails(employee);
        break;
      case 'edit':
        _showEditEmployeeDialog(employee);
        break;
      case 'deactivate':
      case 'activate':
        _toggleEmployeeStatus(employee);
        break;
    }
  }

  void _showEmployeeDetails(User employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', employee.email),
            _buildDetailRow('Role', employee.role.toUpperCase()),
            if (employee.phone != null)
              _buildDetailRow('Phone', employee.phone!),
            if (employee.department != null)
              _buildDetailRow('Department', employee.department!),
            if (employee.designation != null)
              _buildDetailRow('Designation', employee.designation!),
            _buildDetailRow(
              'Status',
              employee.isActive ? 'Active' : 'Inactive',
            ),
            _buildDetailRow(
              'Joined',
              '${employee.createdAt.day}/${employee.createdAt.month}/${employee.createdAt.year}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateEmployeeDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final departmentController = TextEditingController();
    final designationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: designationController,
                decoration: const InputDecoration(
                  labelText: 'Designation',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _createEmployee(
              nameController.text.trim(),
              emailController.text.trim(),
              passwordController.text,
              phoneController.text.trim(),
              departmentController.text.trim(),
              designationController.text.trim(),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createEmployee(
    String name,
    String email,
    String password,
    String phone,
    String department,
    String designation,
  ) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Please fill all required fields');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      Get.snackbar('Error', 'Please enter a valid email');
      return;
    }

    if (password.length < 6) {
      Get.snackbar('Error', 'Password must be at least 6 characters');
      return;
    }

    final success = await authController.createEmployee(
      name: name,
      email: email,
      password: password,
      phone: phone.isEmpty ? null : phone,
      department: department.isEmpty ? null : department,
      designation: designation.isEmpty ? null : designation,
    );

    if (success) {
      Navigator.of(context).pop();
      _loadEmployees();
    }
  }

  void _showEditEmployeeDialog(User employee) {
    // Implementation for editing employee would go here
    Get.snackbar('Info', 'Edit employee feature coming soon!');
  }

  void _toggleEmployeeStatus(User employee) {
    // Implementation for toggling employee status would go here
    Get.snackbar('Info', 'Employee status toggle feature coming soon!');
  }
}
