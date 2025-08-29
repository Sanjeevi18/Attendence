import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../controllers/holiday_controller.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';

class AdminCalendarWidget extends StatefulWidget {
  const AdminCalendarWidget({super.key});

  @override
  State<AdminCalendarWidget> createState() => _AdminCalendarWidgetState();
}

class _AdminCalendarWidgetState extends State<AdminCalendarWidget> {
  final HolidayController holidayController = Get.find<HolidayController>();
  final AuthController authController = Get.find<AuthController>();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    await holidayController.loadHolidays();
    _updateEvents();
  }

  void _updateEvents() {
    final Map<DateTime, List> events = {};
    for (var holiday in holidayController.holidays) {
      final dateKey = DateTime(
        holiday.date.year,
        holiday.date.month,
        holiday.date.day,
      );
      if (events[dateKey] != null) {
        events[dateKey]!.add(holiday);
      } else {
        events[dateKey] = [holiday];
      }
    }
    setState(() {
      _events = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<dynamic>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) => _events[day] ?? [],
          startingDayOfWeek: StartingDayOfWeek.monday,
          onDaySelected: _onDaySelected,
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: const TextStyle(color: Colors.red),
            holidayTextStyle: const TextStyle(color: Colors.red),
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppTheme.secondaryColor,
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
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox();

              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(3).map((event) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 6,
                      width: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedDay != null) _buildSelectedDayEvents(),
      ],
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // Show holiday creation dialog
    _showAddHolidayDialog(selectedDay);
  }

  Widget _buildSelectedDayEvents() {
    final events = _events[_selectedDay] ?? [];

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            Text(
              'No holidays on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap on a date to add a holiday',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Holidays on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((event) => _buildEventItem(event)),
        ],
      ),
    );
  }

  Widget _buildEventItem(dynamic event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 2),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
            onPressed: () => _deleteHoliday(event),
          ),
        ],
      ),
    );
  }

  void _showAddHolidayDialog(DateTime selectedDate) {
    final reasonController = TextEditingController();
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Add Holiday - ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
            style: const TextStyle(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Holiday Title *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Independence Day',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                    hintText: 'Enter holiday description...',
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
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    reasonController.text.trim().isEmpty) {
                  Get.snackbar('Error', 'Please fill all required fields');
                  return;
                }

                try {
                  final success = await holidayController.addHoliday(
                    title: titleController.text.trim(),
                    description: reasonController.text.trim(),
                    date: selectedDate,
                  );

                  if (success) {
                    Navigator.of(context).pop();
                    Get.snackbar(
                      'Success',
                      'Holiday added successfully!',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                    _loadHolidays(); // Refresh calendar
                  }
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Failed to add holiday: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Holiday'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteHoliday(dynamic holiday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to delete "${holiday.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await holidayController.deleteHoliday(holiday.id);
                Navigator.of(context).pop();
                Get.snackbar(
                  'Success',
                  'Holiday deleted successfully!',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
                _loadHolidays(); // Refresh calendar
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to delete holiday: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
