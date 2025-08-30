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
  AttendanceRecord? _selectedDayRecord;
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
        _selectedDayRecord = _attendanceData[_selectedDay];
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
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading attendance data...',
                style: TextStyle(color: Colors.grey),
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

              // Color Legend
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Color Legend:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _buildLegendItem('On Duty', Colors.green),
                        _buildLegendItem('Off Duty', Colors.red),
                        _buildLegendItem('Leave Types', Colors.blue),
                        _buildLegendItem('Work From Home', Colors.purple),
                        _buildLegendItem('Holidays', Colors.deepPurple),
                      ],
                    ),
                  ],
                ),
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
                    _selectedDayRecord = _attendanceData[selectedDay];
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
                                color: Colors.purple,
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

              // Selected Day Details
              if (_selectedDay != null) _buildSelectedDayDetails(),

              const SizedBox(height: 20),

              // Attendance Records List
              _buildAttendanceRecordsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayDetails() {
    final selectedDate = _selectedDay!;
    final record = _selectedDayRecord;
    final holidays = holidayController.getEventsForDay(selectedDate);

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

          if (record == null) ...[
            // No record for this day
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text(
                  'No attendance record for this day',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
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
            ] else if (record.status == 'present') ...[
              // Attendance specific information
              if (record.checkInTime != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Check In',
                  DateFormat('HH:mm').format(record.checkInTime!),
                  Icons.login,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Check In Location',
                  record.checkInLocation,
                  Icons.location_on,
                  Colors.blue,
                ),
              ],

              if (record.checkOutTime != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Check Out',
                  DateFormat('HH:mm').format(record.checkOutTime!),
                  Icons.logout,
                  Colors.red,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Check Out Location',
                  record.checkOutLocation,
                  Icons.location_on,
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Duration',
                  '${record.totalHours.toStringAsFixed(1)} hours',
                  Icons.timer,
                  Colors.purple,
                ),
              ] else if (record.checkInTime != null) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Still checked in',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ],
      ),
    );
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
        return Colors.green; // On duty - Green
      case 'absent':
        return Colors.red; // Off duty/Absent - Red
      case 'leave':
        return Colors.blue; // Leave types - Blue
      case 'approved_leave':
        return Colors.blue; // Approved leave types - Blue
      default:
        return Colors.grey; // Unknown - Grey
    }
  }

  Color _getStatusColorByLeaveType(String status, String? leaveType) {
    if (status.toLowerCase() == 'approved_leave' ||
        status.toLowerCase() == 'leave') {
      if (leaveType?.toLowerCase() == 'workfromhome' ||
          leaveType?.toLowerCase() == 'work from home') {
        return Colors.purple; // Work From Home - Purple
      } else {
        return Colors.blue; // Other leave types - Blue
      }
    }
    return _getStatusColor(status);
  }

  Widget _buildAttendanceRecordsList() {
    if (_attendanceData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.event_note, color: Colors.grey, size: 32),
              SizedBox(height: 8),
              Text(
                'No attendance records found',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Sort records by date (most recent first)
    final sortedEntries = _attendanceData.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.list_alt, color: Colors.black),
            const SizedBox(width: 8),
            const Text(
              'Recent Attendance Records',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            Text(
              '${_attendanceData.length} records',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Records List
        Container(
          height: 300, // Limit height to prevent overflow
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: sortedEntries.length > 5
                ? 5
                : sortedEntries.length, // Show max 5 records to save space
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final date = entry.key;
              final record = entry.value;
              final isToday = isSameDay(date, DateTime.now());

              return Container(
                color: isToday
                    ? Colors.blue.withOpacity(0.05)
                    : Colors.transparent,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColorByLeaveType(
                        record.status,
                        record.leaveType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(record.status),
                      color: _getStatusColorByLeaveType(
                        record.status,
                        record.leaveType,
                      ),
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(date),
                        style: TextStyle(
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (record.status == 'leave' ||
                          record.status == 'approved_leave') ...[
                        Text(
                          '${record.leaveType ?? 'Leave'}: ${record.leaveReason ?? 'No reason provided'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            if (record.checkInTime != null) ...[
                              Icon(Icons.login, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm').format(record.checkInTime!),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (record.checkInTime != null &&
                                record.checkOutTime != null)
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (record.checkOutTime != null) ...[
                              Icon(Icons.logout, size: 12, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'HH:mm',
                                ).format(record.checkOutTime!),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (record.totalHours > 0)
                          Text(
                            '${record.totalHours.toStringAsFixed(1)} hours',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColorByLeaveType(
                        record.status,
                        record.leaveType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColorByLeaveType(
                          record.status,
                          record.leaveType,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      record.status == 'approved_leave'
                          ? 'APPROVED'
                          : record.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColorByLeaveType(
                          record.status,
                          record.leaveType,
                        ),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedDay = date;
                      _selectedDayRecord = record;
                    });
                  },
                ),
              );
            },
          ),
        ),

        if (sortedEntries.length > 5) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Showing 5 of ${sortedEntries.length} records',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ],
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
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
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
