import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/user_model.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final AuthController authController = Get.find<AuthController>();
  final AttendanceController attendanceController = Get.put(
    AttendanceController(),
  );
  bool isEditing = false;

  // Controllers for editing
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();
  final _aadharController = TextEditingController();
  final _panController = TextEditingController();
  final _mobileController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();

  String selectedBloodGroup = 'A+';
  DateTime? selectedDOB;

  final List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final user = authController.currentUser.value;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _departmentController.text = user.department ?? '';
      _designationController.text = user.designation ?? '';
      // Initialize other fields with empty values or existing data
      _aadharController.text = ''; // Add to user model later
      _panController.text = '';
      _mobileController.text = user.phone ?? '';
      _bloodGroupController.text = '';
      _addressController.text = '';
      _ageController.text = '';
      _dobController.text = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _mobileController.dispose();
    _bloodGroupController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (isEditing) {
                _saveProfile();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  isEditing = false;
                });
                _initializeControllers(); // Reset to original values
              },
            ),
        ],
      ),
      body: Obx(() {
        final user = authController.currentUser.value;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 20),
              _buildBasicInformation(),
              const SizedBox(height: 20),
              _buildPersonalDetails(),
              const SizedBox(height: 20),
              _buildProfessionalDetails(),
              const SizedBox(height: 20),
              _buildDocumentDetails(),
              const SizedBox(height: 20),
              _buildAttendanceStats(),
              const SizedBox(height: 20),
              _buildLogoutSection(),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: user.profileImage != null
                    ? ClipOval(
                        child: Image.network(
                          user.profileImage!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(user);
                          },
                        ),
                      )
                    : _buildDefaultAvatar(user),
              ),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _changeProfilePicture,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            authController.currentCompany.value?.name ?? 'Company',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Text(
      user.name.substring(0, 1).toUpperCase(),
      style: const TextStyle(
        color: Colors.indigo,
        fontSize: 48,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBasicInformation() {
    return _buildSection('Basic Information', Icons.person, [
      _buildProfileField('Full Name', _nameController, Icons.person_outline),
      _buildProfileField(
        'Email Address',
        _emailController,
        Icons.email_outlined,
        readOnly: true,
      ),
      _buildProfileField(
        'Phone Number',
        _phoneController,
        Icons.phone_outlined,
      ),
      _buildProfileField(
        'Mobile Number',
        _mobileController,
        Icons.smartphone_outlined,
      ),
    ]);
  }

  Widget _buildPersonalDetails() {
    return _buildSection('Personal Details', Icons.info, [
      _buildDateField('Date of Birth', _dobController, Icons.cake_outlined),
      _buildProfileField(
        'Age',
        _ageController,
        Icons.calendar_today_outlined,
        keyboardType: TextInputType.number,
      ),
      _buildBloodGroupField(),
      _buildProfileField(
        'Address',
        _addressController,
        Icons.home_outlined,
        maxLines: 3,
      ),
    ]);
  }

  Widget _buildProfessionalDetails() {
    return _buildSection('Professional Details', Icons.work, [
      _buildProfileField(
        'Department',
        _departmentController,
        Icons.business_outlined,
      ),
      _buildProfileField(
        'Designation',
        _designationController,
        Icons.work_outline,
      ),
      _buildProfileField(
        'Employee ID',
        TextEditingController(
          text:
              'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        ),
        Icons.badge_outlined,
        readOnly: true,
      ),
      _buildDateField(
        'Joining Date',
        TextEditingController(
          text: DateFormat(
            'dd/MM/yyyy',
          ).format(authController.currentUser.value!.createdAt),
        ),
        Icons.event_outlined,
        readOnly: true,
      ),
    ]);
  }

  Widget _buildDocumentDetails() {
    return _buildSection('Document Details', Icons.description, [
      _buildProfileField(
        'Aadhar Card Number',
        _aadharController,
        Icons.credit_card_outlined,
        keyboardType: TextInputType.number,
      ),
      _buildProfileField(
        'PAN Card Number',
        _panController,
        Icons.account_balance_wallet_outlined,
      ),
    ]);
  }

  Widget _buildAttendanceStats() {
    return _buildSection('This Month Statistics', Icons.assessment, [
      Obx(
        () => Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Present Days',
                '${attendanceController.employeePresentDays.value}',
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Absent Days',
                '${attendanceController.employeeAbsentDays.value}',
                Colors.red,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Obx(
        () => Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Leave Days',
                '${attendanceController.employeeLeaveDays.value}',
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Working Hours',
                attendanceController.formattedWorkingHours,
                Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.indigo, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: !isEditing || readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigo),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
          filled: true,
          fillColor: isEditing && !readOnly ? Colors.white : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(
          color: readOnly ? Colors.grey[600] : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDateField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigo),
          suffixIcon: isEditing && !readOnly
              ? const Icon(Icons.calendar_today, color: Colors.indigo)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
          filled: true,
          fillColor: isEditing && !readOnly ? Colors.white : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onTap: isEditing && !readOnly ? () => _selectDate(controller) : null,
        style: TextStyle(
          color: readOnly ? Colors.grey[600] : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBloodGroupField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: selectedBloodGroup,
        decoration: InputDecoration(
          labelText: 'Blood Group',
          prefixIcon: const Icon(
            Icons.bloodtype_outlined,
            color: Colors.indigo,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
          filled: true,
          fillColor: isEditing ? Colors.white : Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        items: bloodGroups.map((bloodGroup) {
          return DropdownMenuItem(value: bloodGroup, child: Text(bloodGroup));
        }).toList(),
        onChanged: isEditing
            ? (value) {
                setState(() {
                  selectedBloodGroup = value!;
                });
              }
            : null,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLogoutSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          selectedDOB ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDOB) {
      setState(() {
        selectedDOB = picked;
        controller.text = DateFormat('dd/MM/yyyy').format(picked);

        // Calculate age
        final age = DateTime.now().year - picked.year;
        _ageController.text = age.toString();
      });
    }
  }

  void _changeProfilePicture() {
    Get.snackbar('Info', 'Profile picture change feature coming soon!');
  }

  void _saveProfile() {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Name cannot be empty');
      return;
    }

    if (_phoneController.text.trim().isNotEmpty &&
        !GetUtils.isPhoneNumber(_phoneController.text.trim())) {
      Get.snackbar('Error', 'Please enter a valid phone number');
      return;
    }

    // TODO: Implement save functionality with Firebase
    Get.snackbar('Success', 'Profile updated successfully!');
    setState(() {
      isEditing = false;
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              authController.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
