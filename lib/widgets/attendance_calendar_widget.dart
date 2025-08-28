import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/auth_controller.dart';

class AttendanceCalendarWidget extends StatefulWidget {
  const AttendanceCalendarWidget({super.key});

  @override
  State<AttendanceCalendarWidget> createState() =>
      _AttendanceCalendarWidgetState();
}

class _AttendanceCalendarWidgetState extends State<AttendanceCalendarWidget>
    with TickerProviderStateMixin {
  final AuthController authController = Get.find<AuthController>();
  late TabController _tabController;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List> _events = {};
  Map<DateTime, AttendanceStatus> _attendanceData = {};
  Map<DateTime, Map<String, int>> _companyStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = DateTime.now();
    _loadAttendanceData();
    _loadCompanyStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    try {
      final user = authController.currentUser.value;
      if (user == null) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      // Load attendance records for current month
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

      final Map<DateTime, AttendanceStatus> attendanceMap = {};

      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = DateTime(date.year, date.month, date.day);

        if (data['status'] == 'Leave') {
          attendanceMap[dateKey] = AttendanceStatus.leave;
        } else if (data['checkIn'] != null) {
          attendanceMap[dateKey] = AttendanceStatus.present;
        } else {
          attendanceMap[dateKey] = AttendanceStatus.absent;
        }
      }

      // Mark today
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      if (!attendanceMap.containsKey(todayKey)) {
        attendanceMap[todayKey] = AttendanceStatus.today;
      }

      setState(() {
        _attendanceData = attendanceMap;
      });
    } catch (e) {
      print('Error loading attendance data: $e');
    }
  }

  Future<void> _loadCompanyStats() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = authController.currentUser.value;
      if (user == null || user.companyId.isEmpty) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      // Load all company attendance for the current month
      final companyAttendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('companyId', isEqualTo: user.companyId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final Map<DateTime, Map<String, int>> dailyStats = {};

      for (var doc in companyAttendanceQuery.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = DateTime(date.year, date.month, date.day);

        if (!dailyStats.containsKey(dateKey)) {
          dailyStats[dateKey] = {'present': 0, 'absent': 0, 'leave': 0};
        }

        if (data['status'] == 'Leave') {
          dailyStats[dateKey]!['leave'] = dailyStats[dateKey]!['leave']! + 1;
        } else if (data['checkIn'] != null) {
          dailyStats[dateKey]!['present'] =
              dailyStats[dateKey]!['present']! + 1;
        } else {
          dailyStats[dateKey]!['absent'] = dailyStats[dateKey]!['absent']! + 1;
        }
      }

      setState(() {
        _companyStats = dailyStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading company stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Header with tabs
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.indigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Calendar View',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Employee Calendar'),
                Tab(text: 'Company Calendar'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Bar View
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [_buildEmployeeCalendar(), _buildCompanyCalendar()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCalendar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar
          TableCalendar<dynamic>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _events[day] ?? [],
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.red),
              markersMaxCount: 1,
              markerDecoration: const BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dateKey = DateTime(day.year, day.month, day.day);
                final status = _attendanceData[dateKey];

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: status != null ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade700, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadAttendanceData();
              _loadCompanyStats();
            },
          ),

          const SizedBox(height: 16),

          // Legend
          _buildLegend(),

          const SizedBox(height: 16),

          // Selected Day Details
          if (_selectedDay != null) _buildSelectedDayDetails(),
        ],
      ),
    );
  }

  Widget _buildCompanyCalendar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Company-wide calendar view
          TableCalendar<dynamic>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _events[day] ?? [],
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.red),
              markersMaxCount: 1,
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final dateKey = DateTime(day.year, day.month, day.day);
                final stats = _companyStats[dateKey];

                if (stats != null) {
                  final total =
                      stats['present']! + stats['absent']! + stats['leave']!;
                  Color dayColor = Colors.grey.shade200;

                  if (total > 0) {
                    final presentPercentage = stats['present']! / total;
                    if (presentPercentage >= 0.8) {
                      dayColor = Colors.green.shade100;
                    } else if (presentPercentage >= 0.6) {
                      dayColor = Colors.orange.shade100;
                    } else {
                      dayColor = Colors.red.shade100;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: dayColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }

                return null;
              },
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade700, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadCompanyStats();
            },
          ),

          const SizedBox(height: 16),

          // Company Calendar Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Company Attendance Level',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem('High (80%+)', Colors.green.shade100),
                    _buildLegendItem('Medium (60%+)', Colors.orange.shade100),
                    _buildLegendItem('Low (<60%)', Colors.red.shade100),
                    _buildLegendItem('Today', Colors.blue),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Company stats for selected day
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company Overview - ${DateFormat('MMM dd, yyyy').format(_selectedDay ?? DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildCompanyStatsForDay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Present', Colors.green),
          _buildLegendItem('Absent', Colors.red),
          _buildLegendItem('Leave', Colors.blue),
          _buildLegendItem('Today', Colors.orange),
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
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSelectedDayDetails() {
    final dateKey = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final status = _attendanceData[dateKey] ?? AttendanceStatus.absent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDay!),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Status: ${_getStatusText(status)}',
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (status == AttendanceStatus.present) ...[
            const SizedBox(height: 8),
            const Text('Check In: 09:00 AM'),
            const Text('Check Out: 06:00 PM'),
            const Text('Duration: 8h 0m'),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyStatsForDay() {
    final selectedDate = _selectedDay ?? DateTime.now();
    final dateKey = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final stats =
        _companyStats[dateKey] ?? {'present': 0, 'absent': 0, 'leave': 0};

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatChip('Present', '${stats['present']}', Colors.green),
        _buildStatChip('Absent', '${stats['absent']}', Colors.red),
        _buildStatChip('On Leave', '${stats['leave']}', Colors.orange),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.leave:
        return Colors.blue;
      case AttendanceStatus.today:
        return Colors.orange;
      default:
        return Colors.transparent;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.leave:
        return 'On Leave';
      case AttendanceStatus.today:
        return 'Today';
    }
  }
}

enum AttendanceStatus { present, absent, leave, today }
