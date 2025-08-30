import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/auth_controller.dart';
import '../controllers/holiday_controller.dart';
import '../models/holiday_model.dart';

class EnhancedAttendanceCalendarWidget extends StatefulWidget {
  const EnhancedAttendanceCalendarWidget({super.key});

  @override
  State<EnhancedAttendanceCalendarWidget> createState() =>
      _EnhancedAttendanceCalendarWidgetState();
}

class _EnhancedAttendanceCalendarWidgetState
    extends State<EnhancedAttendanceCalendarWidget> {
  final AuthController authController = Get.find<AuthController>();
  final HolidayController holidayController = Get.find<HolidayController>();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, AttendanceRecord> _attendanceData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadAttendanceData();
    // Load holidays for calendar display
    holidayController.loadHolidays();
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = authController.currentUser.value;
      if (user == null) return;

      // Use the focused day instead of current date for month calculation
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      // Load attendance records for focused month
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: user.id)
          .where('companyId', isEqualTo: user.companyId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      // Also load leave records for focused month
      final leaveQuery = await FirebaseFirestore.instance
          .collection('leaves')
          .where('userId', isEqualTo: user.id)
          .where('companyId', isEqualTo: user.companyId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      // Also load approved leave requests for focused month
      final leaveRequestQuery = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('userId', isEqualTo: user.id)
          .where('companyId', isEqualTo: user.companyId)
          .where('status', isEqualTo: 'approved')
          .get();

      final Map<DateTime, AttendanceRecord> attendanceMap = {};

      // Process attendance records
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = DateTime(date.year, date.month, date.day);

        AttendanceRecord record = AttendanceRecord(
          date: dateKey,
          checkInTime: data['checkInTime'] != null
              ? (data['checkInTime'] as Timestamp).toDate()
              : null,
          checkOutTime: data['checkOutTime'] != null
              ? (data['checkOutTime'] as Timestamp).toDate()
              : null,
          checkInLocation: data['checkInLocation'] ?? 'Location not available',
          checkOutLocation:
              data['checkOutLocation'] ?? 'Location not available',
          totalHours: (data['totalHours'] ?? 0.0).toDouble(),
          status: data['status'] ?? 'unknown',
          leaveType: null,
          leaveReason: null,
        );

        attendanceMap[dateKey] = record;
      }

      // Process leave records
      for (var doc in leaveQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = DateTime(date.year, date.month, date.day);

        AttendanceRecord record = AttendanceRecord(
          date: dateKey,
          checkInTime: null,
          checkOutTime: null,
          checkInLocation: 'On Leave',
          checkOutLocation: 'On Leave',
          totalHours: 0.0,
          status: 'leave',
          leaveType: data['leaveType'] ?? 'Unknown',
          leaveReason: data['reason'] ?? 'No reason provided',
        );

        attendanceMap[dateKey] = record;
      }

      // Process approved leave request records
      for (var doc in leaveRequestQuery.docs) {
        final data = doc.data();
        final fromDate = (data['fromDate'] as Timestamp).toDate();
        final toDate = (data['toDate'] as Timestamp).toDate();

        // Generate records for each day in the leave request range
        for (
          DateTime date = fromDate;
          date.isBefore(toDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))
        ) {
          final dateKey = DateTime(date.year, date.month, date.day);

          // Only add if it's within the focused month
          if (dateKey.year == _focusedDay.year &&
              dateKey.month == _focusedDay.month) {
            AttendanceRecord record = AttendanceRecord(
              date: dateKey,
              checkInTime: null,
              checkOutTime: null,
              checkInLocation: 'On Leave',
              checkOutLocation: 'On Leave',
              totalHours: 0.0,
              status: 'approved_leave',
              leaveType: data['leaveType'] ?? 'Unknown',
              leaveReason: data['reason'] ?? 'No reason provided',
            );

            attendanceMap[dateKey] = record;
          }
        }
      }

      setState(() {
        _attendanceData = attendanceMap;
      });
    } catch (e) {
      print('Error loading attendance data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Loading attendance data...',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height:
            MediaQuery.of(context).size.height *
            0.75, // Reduce to 75% of screen height
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.black),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Attendance Calendar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                    onPressed: () {
                      _loadAttendanceData();
                      holidayController.loadHolidays();
                    },
                    tooltip: 'Refresh calendar data',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Calendar
              TableCalendar<dynamic>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  List<dynamic> events = [];

                  // Add attendance record if exists
                  final record = _attendanceData[day];
                  if (record != null) {
                    events.add(record);
                  }

                  // Add holidays if exist
                  final holidays = holidayController.getEventsForDay(day);
                  events.addAll(holidays);

                  // Add Sunday as default holiday
                  if (day.weekday == DateTime.sunday) {
                    events.add(
                      Holiday(
                        id: 'sunday_${day.toIso8601String().split('T')[0]}',
                        companyId:
                            authController.currentUser.value?.companyId ?? '',
                        title: 'Sunday',
                        description: 'Weekly Holiday',
                        date: day,
                        type: 'weekly',
                        isRecurring: true,
                        createdAt: DateTime.now(),
                        createdBy: 'system',
                      ),
                    );
                  }

                  return events;
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
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
                      List<Widget> markers = [];

                      // Check for attendance record
                      final attendanceRecord = events
                          .whereType<AttendanceRecord>()
                          .firstOrNull;
                      if (attendanceRecord != null) {
                        Color markerColor;
                        if (attendanceRecord.status == 'present' &&
                            attendanceRecord.checkOutTime != null) {
                          markerColor = Colors.green; // On duty - Green
                        } else if (attendanceRecord.status == 'present' &&
                            attendanceRecord.checkOutTime == null) {
                          markerColor =
                              Colors.orange; // Checked in but not out - Orange
                        } else if (attendanceRecord.status ==
                            'approved_leave') {
                          // Different colors for different leave types
                          if (attendanceRecord.leaveType?.toLowerCase() ==
                                  'workfromhome' ||
                              attendanceRecord.leaveType?.toLowerCase() ==
                                  'work from home') {
                            markerColor =
                                Colors.purple; // Work From Home - Purple
                          } else {
                            markerColor =
                                Colors.blue; // Other leave types - Blue
                          }
                        } else if (attendanceRecord.status == 'leave') {
                          // Legacy leave records
                          if (attendanceRecord.leaveType?.toLowerCase() ==
                                  'workfromhome' ||
                              attendanceRecord.leaveType?.toLowerCase() ==
                                  'work from home') {
                            markerColor =
                                Colors.purple; // Work From Home - Purple
                          } else {
                            markerColor =
                                Colors.blue; // Other leave types - Blue
                          }
                        } else if (attendanceRecord.status == 'absent') {
                          markerColor = Colors.red; // Off duty/Absent - Red
                        } else {
                          markerColor = Colors.grey; // Unknown status - Grey
                        }

                        markers.add(
                          Positioned(
                            bottom: 1,
                            left: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }

                      // Check for holidays
                      final holidays = events.whereType<Holiday>().toList();
                      if (holidays.isNotEmpty) {
                        markers.add(
                          Positioned(
                            bottom: 1,
                            right: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.pink,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }

                      return Stack(children: markers);
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Selected Day Details (re-added with enhanced info)
              if (_selectedDay != null) _buildEnhancedDayDetails(),

              const SizedBox(height: 20),

              // Calendar Legend at the bottom
              _buildCalendarLegend(),

              const SizedBox(height: 20),

              // Recent Attendance Records
              _buildAttendanceRecords(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceRecords() {
    // Get recent attendance records (last 7 days)
    final now = DateTime.now();
    final recentRecords = <AttendanceRecord>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final record = _attendanceData[DateTime(date.year, date.month, date.day)];
      if (record != null) {
        recentRecords.add(record);
      }
    }

    if (recentRecords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No recent attendance records',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Recent Attendance (Last 7 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentRecords.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = recentRecords[index];
              return _buildAttendanceRecordItem(record);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDayDetails() {
    final selectedDate = _selectedDay!;
    final record = _attendanceData[selectedDate];
    final holidays = holidayController.getEventsForDay(selectedDate);
    final isToday = isSameDay(selectedDate, DateTime.now());
    final isFutureDate = selectedDate.isAfter(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Row(
            children: [
              Icon(Icons.event, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Holiday Information (if any)
          if (holidays.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.celebration, color: Colors.purple, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Holiday',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...holidays.map(
                    (holiday) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${holiday.title}',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Future Date - Show N/A
          if (isFutureDate) ...[
            _buildDetailRow('Status', 'N/A', Icons.help, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Check In Time', 'N/A', Icons.login, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Check Out Time', 'N/A', Icons.logout, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Duration', 'N/A', Icons.timer, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Location', 'N/A', Icons.location_on, Colors.grey),
          ] else if (record == null) ...[
            // No record for this day - Show N/A
            _buildDetailRow(
              'Status',
              'No Record',
              Icons.info_outline,
              Colors.grey,
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Check In Time', 'N/A', Icons.login, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Check Out Time', 'N/A', Icons.logout, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Duration', 'N/A', Icons.timer, Colors.grey),
            const SizedBox(height: 8),
            _buildDetailRow('Location', 'N/A', Icons.location_on, Colors.grey),
          ] else ...[
            // Attendance details
            _buildDetailRow(
              'Status',
              record.status == 'approved_leave'
                  ? 'APPROVED LEAVE'
                  : record.status.toUpperCase(),
              _getStatusIcon(record.status),
              _getStatusColorByLeaveType(record.status, record.leaveType),
            ),

            if (record.status == 'leave' ||
                record.status == 'approved_leave') ...[
              // Leave specific information
              const SizedBox(height: 8),
              _buildDetailRow(
                'Leave Type',
                record.leaveType ?? 'Unknown',
                record.leaveType?.toLowerCase() == 'workfromhome' ||
                        record.leaveType?.toLowerCase() == 'work from home'
                    ? Icons.home_work
                    : Icons.category,
                _getStatusColorByLeaveType(record.status, record.leaveType),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Reason',
                record.leaveReason ?? 'No reason provided',
                Icons.note,
                _getStatusColorByLeaveType(record.status, record.leaveType),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Check In Time', 'N/A', Icons.login, Colors.grey),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Check Out Time',
                'N/A',
                Icons.logout,
                Colors.grey,
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Duration', 'N/A', Icons.timer, Colors.grey),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Location',
                'N/A',
                Icons.location_on,
                Colors.grey,
              ),
            ] else if (record.status == 'present') ...[
              // Attendance specific information
              const SizedBox(height: 8),
              _buildDetailRow(
                'Check In Time',
                record.checkInTime != null
                    ? DateFormat('HH:mm').format(record.checkInTime!)
                    : 'N/A',
                Icons.login,
                record.checkInTime != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Check Out Time',
                record.checkOutTime != null
                    ? DateFormat('HH:mm').format(record.checkOutTime!)
                    : (record.checkInTime != null ? 'Still Checked In' : 'N/A'),
                Icons.logout,
                record.checkOutTime != null
                    ? Colors.red
                    : (record.checkInTime != null
                          ? Colors.orange
                          : Colors.grey),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Duration',
                _calculateDuration(record.checkInTime, record.checkOutTime),
                Icons.timer,
                record.totalHours > 0 ? Colors.purple : Colors.grey,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Check In Location',
                record.checkInLocation.isNotEmpty
                    ? record.checkInLocation
                    : 'N/A',
                Icons.location_on,
                record.checkInLocation.isNotEmpty ? Colors.blue : Colors.grey,
              ),
              if (record.checkOutTime != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Check Out Location',
                  record.checkOutLocation.isNotEmpty
                      ? record.checkOutLocation
                      : 'N/A',
                  Icons.location_on,
                  record.checkOutLocation.isNotEmpty
                      ? Colors.blue
                      : Colors.grey,
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  String _calculateDuration(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null) return 'N/A';

    final endTime = checkOut ?? DateTime.now();
    final duration = endTime.difference(checkIn);

    if (duration.inMinutes < 1) return '0 minutes';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'leave':
        return Icons.event_available;
      case 'approved_leave':
        return Icons.event_available;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'leave':
        return Colors.blue;
      case 'approved_leave':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColorByLeaveType(String status, String? leaveType) {
    if (status.toLowerCase() == 'approved_leave' ||
        status.toLowerCase() == 'leave') {
      if (leaveType?.toLowerCase() == 'workfromhome' ||
          leaveType?.toLowerCase() == 'work from home') {
        return Colors.purple;
      } else {
        return Colors.blue;
      }
    }
    return _getStatusColor(status);
  }

  Widget _buildAttendanceRecordItem(AttendanceRecord record) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (record.status == 'present') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Present';
    } else if (record.status == 'leave') {
      statusColor =
          record.leaveType?.toLowerCase() == 'workfromhome' ||
              record.leaveType?.toLowerCase() == 'work from home'
          ? Colors.purple
          : Colors.blue;
      statusIcon = Icons.event_busy;
      statusText = record.leaveType ?? 'Leave';
    } else if (record.status == 'absent') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Absent';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = record.status.toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(statusIcon, color: statusColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateFormat.format(record.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (record.status == 'present') ...[
                  Row(
                    children: [
                      if (record.checkInTime != null) ...[
                        Icon(Icons.login, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'In: ${timeFormat.format(record.checkInTime!)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (record.checkOutTime != null) ...[
                        Icon(Icons.logout, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Out: ${timeFormat.format(record.checkOutTime!)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Still on duty',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (record.totalHours > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Duration: ${record.totalHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else if (record.status == 'leave' &&
                    record.leaveReason != null) ...[
                  Text(
                    record.leaveReason!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendar Legend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // First row
          Row(
            children: [
              Expanded(
                child: _buildLegendItem('Present (Full Day)', Colors.green),
              ),
              Expanded(
                child: _buildLegendItem('Present (Partial)', Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row
          Row(
            children: [
              Expanded(child: _buildLegendItem('Leave', Colors.blue)),
              Expanded(
                child: _buildLegendItem('Work From Home', Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Third row
          Row(
            children: [
              Expanded(child: _buildLegendItem('Absent', Colors.red)),
              Expanded(child: _buildLegendItem('Holiday/Sunday', Colors.pink)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}

class AttendanceRecord {
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String checkInLocation;
  final String checkOutLocation;
  final double totalHours;
  final String status;
  final String? leaveType;
  final String? leaveReason;

  AttendanceRecord({
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.checkInLocation,
    required this.checkOutLocation,
    required this.totalHours,
    required this.status,
    this.leaveType,
    this.leaveReason,
  });
}
