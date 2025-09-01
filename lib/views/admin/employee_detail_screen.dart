import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comprehensive_attendance_calendar_widget.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/auth_controller.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final User employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AttendanceController attendanceController =
      Get.find<AttendanceController>();
  final AuthController authController = Get.find<AuthController>();

  // Employee stats
  int presentDays = 0;
  int absentDays = 0;
  int leaveDays = 0;
  int workingHours = 0;
  bool isLoadingStats = true;

  // Location data
  Map<String, dynamic>? currentLocationData;
  List<Map<String, dynamic>> locationHistory = [];
  bool isLoadingLocation = true;

  // Recent attendance
  List<Map<String, dynamic>> recentAttendance = [];
  bool isLoadingAttendance = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    await Future.wait([
      _loadEmployeeStats(),
      _loadLocationData(),
      _loadRecentAttendance(),
    ]);
  }

  Future<void> _loadEmployeeStats() async {
    try {
      setState(() {
        isLoadingStats = true;
      });

      // Get current month's data directly from Firebase
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      final startDateStr = DateFormat('yyyy-MM-dd').format(monthStart);
      final endDateStr = DateFormat('yyyy-MM-dd').format(monthEnd);

      // Get attendance records for current month
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: widget.employee.id)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThan: endDateStr)
          .get();

      int presentCount = 0;
      int totalMinutes = 0;

      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'present') {
          presentCount++;
          if (data['totalDuration'] != null) {
            totalMinutes += (data['totalDuration'] as num).toInt();
          }
        }
      }

      final totalHours = (totalMinutes / 60).round();
      presentDays = presentCount;
      workingHours = totalHours;

      // Get leave requests for current month
      final leaveQuery = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('userId', isEqualTo: widget.employee.id)
          .where('status', isEqualTo: 'approved')
          .get();

      int totalLeaveDays = 0;
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        // Calculate days in current month
        DateTime checkDate = fromDate;
        while (checkDate.isBefore(toDate.add(const Duration(days: 1)))) {
          if (checkDate.month == now.month && checkDate.year == now.year) {
            totalLeaveDays++;
          }
          checkDate = checkDate.add(const Duration(days: 1));
        }
      }

      leaveDays = totalLeaveDays;

      // Calculate absent days properly: working days - present days - approved leave days
      // But only count up to current date for accurate calculation
      final today = DateTime.now();
      final endDateForCalculation =
          today.month == now.month && today.year == now.year
          ? today
          : DateTime(
              now.year,
              now.month + 1,
              0,
            ); // End of month if not current month

      final workingDaysUpToNow = _calculateWorkingDaysUpToDate(
        monthStart,
        endDateForCalculation,
      );

      // Absent days = working days that passed - (present days + approved leave days)
      absentDays = (workingDaysUpToNow - presentDays - leaveDays).clamp(
        0,
        workingDaysUpToNow,
      );

      setState(() {
        isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading employee stats: $e');
      setState(() {
        isLoadingStats = false;
      });
    }
  }

  int _calculateWorkingDaysUpToDate(DateTime start, DateTime end) {
    int workingDays = 0;
    DateTime current = start;

    while (current.isBefore(end.add(const Duration(days: 1))) &&
        current.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      // Exclude Sundays (weekday 7) - only count Monday to Saturday as working days
      if (current.weekday != DateTime.sunday) {
        workingDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  Color _getEmployeeStatusColor() {
    if (currentLocationData != null &&
        currentLocationData!['isOnDuty'] == true) {
      return Colors.green; // On duty
    } else if (widget.employee.isActive) {
      return Colors.orange; // Active but off duty
    } else {
      return Colors.red; // Inactive
    }
  }

  String _getEmployeeStatusText() {
    if (currentLocationData != null &&
        currentLocationData!['isOnDuty'] == true) {
      return 'On Duty';
    } else if (widget.employee.isActive) {
      return 'Off Duty';
    } else {
      return 'Inactive';
    }
  }

  Future<void> _loadLocationData() async {
    try {
      setState(() {
        isLoadingLocation = true;
      });

      final locationData = await attendanceController.getEmployeeLocationData(
        widget.employee.id,
      );
      currentLocationData = locationData;

      // Load recent location history from attendance records
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final startDateStr = DateFormat('yyyy-MM-dd').format(oneWeekAgo);
      final endDateStr = DateFormat('yyyy-MM-dd').format(now);

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: widget.employee.id)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .get();

      // Convert attendance data to location history
      locationHistory.clear();
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();

        if (data['dutyStartTime'] != null) {
          final startTime = (data['dutyStartTime'] as Timestamp).toDate();
          locationHistory.add({
            'time': DateFormat('MMM dd HH:mm').format(startTime),
            'action': 'Check In',
            'location': data['checkInAddress'] ?? 'Location not available',
            'coordinates': data['checkInLocation'],
          });
        }

        if (data['dutyEndTime'] != null) {
          final endTime = (data['dutyEndTime'] as Timestamp).toDate();
          locationHistory.add({
            'time': DateFormat('MMM dd HH:mm').format(endTime),
            'action': 'Check Out',
            'location': data['checkOutAddress'] ?? 'Location not available',
            'coordinates': data['checkOutLocation'],
          });
        }
      }

      // Sort by time descending
      locationHistory.sort((a, b) => b['time'].compareTo(a['time']));

      setState(() {
        isLoadingLocation = false;
      });
    } catch (e) {
      print('Error loading location data: $e');
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadRecentAttendance() async {
    try {
      setState(() {
        isLoadingAttendance = true;
      });

      // Get recent 7 days of attendance
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final startDateStr = DateFormat('yyyy-MM-dd').format(oneWeekAgo);
      final endDateStr = DateFormat('yyyy-MM-dd').format(now);

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: widget.employee.id)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .orderBy('date', descending: true)
          .get();

      // Convert to recent attendance list
      recentAttendance.clear();
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String;
        final date = DateTime.parse(dateStr);

        String displayDate;
        if (DateFormat('yyyy-MM-dd').format(now) == dateStr) {
          displayDate = 'Today';
        } else if (DateFormat(
              'yyyy-MM-dd',
            ).format(now.subtract(const Duration(days: 1))) ==
            dateStr) {
          displayDate = 'Yesterday';
        } else {
          displayDate = DateFormat('MMM dd').format(date);
        }

        String details;
        Color color;

        switch (data['status']) {
          case 'present':
            color = Colors.green;
            if (data['isOnDuty'] == true) {
              final checkInTime = data['dutyStartTime'] != null
                  ? DateFormat(
                      'hh:mm a',
                    ).format((data['dutyStartTime'] as Timestamp).toDate())
                  : 'Unknown';
              details = '$checkInTime - Working';
            } else if (data['dutyStartTime'] != null &&
                data['dutyEndTime'] != null) {
              final checkInTime = DateFormat(
                'hh:mm a',
              ).format((data['dutyStartTime'] as Timestamp).toDate());
              final checkOutTime = DateFormat(
                'hh:mm a',
              ).format((data['dutyEndTime'] as Timestamp).toDate());
              details = '$checkInTime - $checkOutTime';
            } else {
              details = 'Present';
            }
            break;
          case 'leave':
            color = Colors.orange;
            details = 'Leave';
            break;
          default:
            color = Colors.red;
            details = 'Absent';
        }

        recentAttendance.add({
          'date': displayDate,
          'status': (data['status'] ?? 'absent').toString().toUpperCase(),
          'details': details,
          'color': color,
        });
      }

      setState(() {
        isLoadingAttendance = false;
      });
    } catch (e) {
      print('Error loading recent attendance: $e');
      setState(() {
        isLoadingAttendance = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee.name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadEmployeeData();
            },
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _editEmployee),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildCalendarTab(),
          _buildLocationTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 24), text: 'Profile'),
            Tab(icon: Icon(Icons.calendar_month, size: 24), text: 'Calendar'),
            Tab(icon: Icon(Icons.location_on, size: 24), text: 'Location'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          _buildProfileDetails(),
          const SizedBox(height: 20),
          _buildEmployeeStats(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: widget.employee.role == 'admin'
                ? Colors.red
                : AppTheme.primaryColor,
            child: widget.employee.profileImage != null
                ? ClipOval(
                    child: Image.network(
                      widget.employee.profileImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    ),
                  )
                : _buildDefaultAvatar(),
          ),
          const SizedBox(height: 16),
          Text(
            widget.employee.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.employee.role == 'admin'
                  ? Colors.red.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.employee.role == 'admin'
                    ? Colors.red
                    : Colors.blue,
              ),
            ),
            child: Text(
              widget.employee.role.toUpperCase(),
              style: TextStyle(
                color: widget.employee.role == 'admin'
                    ? Colors.red
                    : Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getEmployeeStatusColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getEmployeeStatusText(),
                style: TextStyle(
                  color: _getEmployeeStatusColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Text(
      widget.employee.name.substring(0, 1).toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Email', widget.employee.email, Icons.email),
          if (widget.employee.phone != null)
            _buildDetailRow('Phone', widget.employee.phone!, Icons.phone),
          if (widget.employee.department != null)
            _buildDetailRow(
              'Department',
              widget.employee.department!,
              Icons.business,
            ),
          if (widget.employee.designation != null)
            _buildDetailRow(
              'Designation',
              widget.employee.designation!,
              Icons.work,
            ),
          _buildDetailRow(
            'Joined Date',
            DateFormat('MMM dd, yyyy').format(widget.employee.createdAt),
            Icons.calendar_today,
          ),
          if (widget.employee.lastLoginAt != null)
            _buildDetailRow(
              'Last Login',
              DateFormat(
                'MMM dd, yyyy - HH:mm',
              ).format(widget.employee.lastLoginAt!),
              Icons.access_time,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Month Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (isLoadingStats) ...[
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Present Days',
                    '$presentDays',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Absent Days',
                    '$absentDays',
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Leave Days',
                    '$leaveDays',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Working Hours',
                    '${workingHours}h',
                    AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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

  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar widget with employee parameter
          ComprehensiveAttendanceCalendarWidget(employee: widget.employee),
          const SizedBox(height: 20),
          _buildAttendanceHistory(),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Attendance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (isLoadingAttendance) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (recentAttendance.isEmpty) ...[
            const Center(
              child: Text(
                'No recent attendance data',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ] else ...[
            ...recentAttendance
                .map(
                  (attendance) => _buildAttendanceItem(
                    attendance['date'],
                    attendance['status'],
                    attendance['details'],
                    attendance['color'],
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(
    String date,
    String status,
    String details,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  details,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentLocation(),
          const SizedBox(height: 20),
          _buildLocationHistory(),
        ],
      ),
    );
  }

  Widget _buildCurrentLocation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Current Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingLocation) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Map View Coming Soon',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  if (currentLocationData != null &&
                      currentLocationData!['isOnDuty'] == true) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Currently On Duty'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (currentLocationData!['lastLocationAddress'] !=
                        null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Location: ${currentLocationData!['lastLocationAddress']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Location: Not available',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (currentLocationData!['lastActivityTime'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last update: ${DateFormat('HH:mm').format(currentLocationData!['lastActivityTime'].toDate())}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Off Duty'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last seen: ${currentLocationData?['lastActivityTime'] != null ? DateFormat('MMM dd, HH:mm').format(currentLocationData!['lastActivityTime'].toDate()) : 'Unknown'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (isLoadingLocation) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (locationHistory.isEmpty) ...[
            const Center(
              child: Text(
                'No location history available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ] else ...[
            ...locationHistory
                .take(5)
                .map(
                  (location) => _buildLocationHistoryItem(
                    location['time'],
                    location['action'],
                    location['location'],
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationHistoryItem(
    String time,
    String action,
    String location,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: action == 'Check In'
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              action == 'Check In' ? Icons.login : Icons.logout,
              color: action == 'Check In' ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  location,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editEmployee() {
    Get.snackbar('Info', 'Edit employee feature coming soon!');
  }
}
