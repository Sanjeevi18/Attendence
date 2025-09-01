import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/holiday_controller.dart';
import '../models/user_model.dart';

class ComprehensiveAttendanceCalendarWidget extends StatefulWidget {
  final User? employee; // Optional employee parameter for admin view

  const ComprehensiveAttendanceCalendarWidget({super.key, this.employee});

  @override
  State<ComprehensiveAttendanceCalendarWidget> createState() =>
      _ComprehensiveAttendanceCalendarWidgetState();
}

class _ComprehensiveAttendanceCalendarWidgetState
    extends State<ComprehensiveAttendanceCalendarWidget> {
  final AttendanceController attendanceController =
      Get.find<AttendanceController>();
  final AuthController authController = Get.find<AuthController>();
  final HolidayController holidayController = Get.find<HolidayController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, Map<String, dynamic>> _monthlyAttendanceData = {};
  Map<String, dynamic>? _selectedDayData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadAttendanceData();
    _loadSelectedDayData();
  }

  Future<void> _loadAttendanceData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      // Use the specific employee or current user
      final targetUserId =
          widget.employee?.id ?? authController.currentUser.value?.id;
      if (targetUserId != null) {
        _monthlyAttendanceData = await _getAttendanceForEmployee(
          targetUserId,
          startOfMonth,
          endOfMonth,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSelectedDayData() async {
    if (_selectedDay == null) return;

    try {
      // Use the specific employee or current user
      final targetUserId =
          widget.employee?.id ?? authController.currentUser.value?.id;
      if (targetUserId != null) {
        final data = await _getAttendanceForEmployeeDate(
          targetUserId,
          _selectedDay!,
        );
        if (mounted) {
          setState(() {
            _selectedDayData = data;
          });
        }
      }
    } catch (e) {
      print('Error loading selected day data: $e');
    }
  }

  // Helper method to get attendance for a specific employee
  Future<Map<String, Map<String, dynamic>>> _getAttendanceForEmployee(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, Map<String, dynamic>> attendanceMap = {};

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      // Fetch attendance records for the date range
      // Using a simpler query to avoid index requirement temporarily
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: employeeId)
          .get();

      // Filter results in memory for date range until index is created
      final filteredDocs = attendanceQuery.docs.where((doc) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr == null) return false;

        // Simple date comparison
        return dateStr.compareTo(startDateStr) >= 0 &&
            dateStr.compareTo(endDateStr) <= 0;
      }).toList();

      // Process attendance records
      for (var doc in filteredDocs) {
        final data = doc.data();
        final dateStr = data['date'] as String;

        final dutyStart = data['dutyStartTime'] != null
            ? (data['dutyStartTime'] as Timestamp).toDate()
            : null;
        final dutyEnd = data['dutyEndTime'] != null
            ? (data['dutyEndTime'] as Timestamp).toDate()
            : null;

        String? totalDuration;
        if (data['totalDurationFormatted'] != null) {
          totalDuration = data['totalDurationFormatted'];
        } else if (data['totalDuration'] != null) {
          final minutes = data['totalDuration'] as int;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          totalDuration = '${hours}h ${mins}m';
        }

        attendanceMap[dateStr] = {
          'status': data['status'] ?? 'absent',
          'isOnDuty': data['isOnDuty'] ?? false,
          'dutyStartTime': dutyStart,
          'dutyEndTime': dutyEnd,
          'checkInTime': dutyStart != null
              ? DateFormat('hh:mm a').format(dutyStart)
              : null,
          'checkOutTime': dutyEnd != null
              ? DateFormat('hh:mm a').format(dutyEnd)
              : null,
          'totalDuration': totalDuration ?? 'N/A',
          'checkInAddress': data['checkInAddress'] ?? 'Location not available',
          'checkOutAddress':
              data['checkOutAddress'] ??
              (dutyEnd != null ? 'Location not available' : null),
          'checkInLocation': data['checkInLocation'],
          'checkOutLocation': data['checkOutLocation'],
        };
      }

      return attendanceMap;
    } catch (e) {
      print('Error getting attendance for employee: $e');
      return attendanceMap;
    }
  }

  // Helper method to get attendance for a specific employee and date
  Future<Map<String, dynamic>> _getAttendanceForEmployeeDate(
    String employeeId,
    DateTime date,
  ) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Check if it's today and for current user (to show real-time status)
      if (DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr &&
          employeeId == authController.currentUser.value?.id) {
        if (attendanceController.onDuty.value) {
          return {
            'status': 'present',
            'isOnDuty': true,
            'dutyStartTime': attendanceController.dutyStartTime.value,
            'currentDuration': attendanceController.currentWorkingTime.value,
            'checkInTime': attendanceController.dutyStartTime.value != null
                ? DateFormat(
                    'hh:mm a',
                  ).format(attendanceController.dutyStartTime.value!)
                : null,
            'checkOutTime': null,
            'totalDuration': attendanceController.currentWorkingTime.value,
            'checkInAddress': 'Current location',
            'checkOutAddress': null,
          };
        }
      }

      // Fetch attendance record from Firestore
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc('${employeeId}_$dateStr')
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;

        final dutyStart = data['dutyStartTime'] != null
            ? (data['dutyStartTime'] as Timestamp).toDate()
            : null;
        final dutyEnd = data['dutyEndTime'] != null
            ? (data['dutyEndTime'] as Timestamp).toDate()
            : null;

        String? totalDuration;
        if (data['totalDurationFormatted'] != null) {
          totalDuration = data['totalDurationFormatted'];
        } else if (data['totalDuration'] != null) {
          final minutes = data['totalDuration'] as int;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          totalDuration = '${hours}h ${mins}m';
        }

        return {
          'status': data['status'] ?? 'absent',
          'isOnDuty': data['isOnDuty'] ?? false,
          'dutyStartTime': dutyStart,
          'dutyEndTime': dutyEnd,
          'checkInTime': dutyStart != null
              ? DateFormat('hh:mm a').format(dutyStart)
              : null,
          'checkOutTime': dutyEnd != null
              ? DateFormat('hh:mm a').format(dutyEnd)
              : null,
          'totalDuration': totalDuration ?? 'N/A',
          'checkInAddress': data['checkInAddress'] ?? 'Location not available',
          'checkOutAddress':
              data['checkOutAddress'] ??
              (dutyEnd != null ? 'Location not available' : null),
          'checkInLocation': data['checkInLocation'],
          'checkOutLocation': data['checkOutLocation'],
        };
      }

      // Default absent status
      return {
        'status': 'absent',
        'isOnDuty': false,
        'checkInTime': null,
        'checkOutTime': null,
        'totalDuration': 'N/A',
        'checkInAddress': null,
        'checkOutAddress': null,
      };
    } catch (e) {
      print('Error getting attendance for employee date: $e');
      return {'status': 'absent', 'isOnDuty': false, 'error': e.toString()};
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.black87;
      case 'leave':
        return Colors.black54;
      case 'absent':
        return Colors.black38;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'leave':
        return Icons.event_busy;
      case 'absent':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.black),
                const SizedBox(width: 8),
                const Text(
                  'Attendance Calendar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar
            TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) {
                final dateStr = DateFormat('yyyy-MM-dd').format(day);
                return _monthlyAttendanceData.containsKey(dateStr)
                    ? [_monthlyAttendanceData[dateStr]!]
                    : [];
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                markersMaxCount: 1,
                markerDecoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadSelectedDayData();
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                _loadAttendanceData();
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    final data = events.first;
                    final status = data['status'] ?? 'absent';

                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    );
                  }
                  return null;
                },
                selectedBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black87, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Legend
            _buildLegend(),

            const SizedBox(height: 12),

            // Selected Day Details
            if (_selectedDay != null) _buildSelectedDayDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Present', Colors.green, Icons.check_circle),
          _buildLegendItem('Leave', Colors.blue, Icons.event_busy),
          _buildLegendItem('Absent', Colors.red, Icons.cancel),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayDetails() {
    final isToday = isSameDay(_selectedDay, DateTime.now());
    final isFutureDate = _selectedDay!.isAfter(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple Date Header
          Row(
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(_selectedDay!),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (isFutureDate) ...[
            _buildSimpleRow('Future Date', Icons.schedule, Colors.grey),
          ] else if (_selectedDayData == null) ...[
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else ...[
            // Status
            _buildSimpleRow(
              (_selectedDayData!['status'] ?? 'N/A').toString().toUpperCase(),
              _getStatusIcon(_selectedDayData!['status'] ?? 'absent'),
              _getStatusColor(_selectedDayData!['status'] ?? 'absent'),
            ),

            // Quick Summary (if all time data is available)
            if (_selectedDayData!['checkInTime'] != null &&
                _selectedDayData!['checkOutTime'] != null &&
                _selectedDayData!['totalDuration'] != null &&
                _selectedDayData!['totalDuration'] != 'N/A') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: Colors.blue.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_selectedDayData!['checkInTime']} → ${_selectedDayData!['checkOutTime']} (${_selectedDayData!['totalDuration']})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedDayData!['checkInTime'] != null ||
                _selectedDayData!['checkOutTime'] != null ||
                _selectedDayData!['totalDuration'] != null) ...[
              // Detailed Time Info (when summary is not complete)
              const SizedBox(height: 6),

              // Check-in Time
              if (_selectedDayData!['checkInTime'] != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.login,
                      size: 14,
                      color: Colors.green.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'In: ${_selectedDayData!['checkInTime']!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Check-out Time
              if (_selectedDayData!['checkOutTime'] != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.logout,
                      size: 14,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Out: ${_selectedDayData!['checkOutTime']!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ] else if (_selectedDayData!['isOnDuty'] == true) ...[
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.orange.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Still On Duty',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Duration
              if (_selectedDayData!['totalDuration'] != null &&
                  _selectedDayData!['totalDuration'] != 'N/A') ...[
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: Colors.purple.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: ${_selectedDayData!['totalDuration']!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            // Location (simplified)
            if (_selectedDayData!['checkInAddress'] != null &&
                _selectedDayData!['checkInAddress'] != 'N/A') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.blue.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _selectedDayData!['checkInAddress']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleRow(String text, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
