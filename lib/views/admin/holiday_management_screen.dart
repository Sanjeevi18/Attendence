import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../controllers/holiday_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/holiday_model.dart';

class HolidayManagementScreen extends StatefulWidget {
  const HolidayManagementScreen({super.key});

  @override
  State<HolidayManagementScreen> createState() =>
      _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen> {
  final HolidayController holidayController = Get.put(HolidayController());
  final AuthController authController = Get.find<AuthController>();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => holidayController.refreshHolidays(),
          ),
        ],
      ),
      body: Column(children: [_buildCalendarSection(), _buildHolidaysList()]),
      floatingActionButton: authController.isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddHolidayDialog(),
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Obx(() {
        return TableCalendar<Holiday>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: (day) => holidayController.getEventsForDay(day),
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

          // Calendar styling
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: const TextStyle(color: Colors.red),
            holidayTextStyle: const TextStyle(color: Colors.red),
            selectedDecoration: const BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
            ),
            todayDecoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),

          // Custom day builder to show holidays marked as leave with special styling
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final holidays = holidayController.getEventsForDay(day);
              final hasMarkedLeaveHoliday = holidays.any(
                (h) => h.markedAsLeave,
              );

              if (hasMarkedLeaveHoliday) {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
              return null;
            },
            outsideBuilder: (context, day, focusedDay) {
              final holidays = holidayController.getEventsForDay(day);
              final hasMarkedLeaveHoliday = holidays.any(
                (h) => h.markedAsLeave,
              );

              if (hasMarkedLeaveHoliday) {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }
              return null;
            },
            markerBuilder: (context, day, events) {
              if (events.isNotEmpty) {
                final holidays = events.cast<Holiday>();
                final hasMarkedLeave = holidays.any((h) => h.markedAsLeave);

                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasMarkedLeave
                          ? Colors.red.shade700
                          : Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }
              return null;
            },
          ),

          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonShowsNext: false,
            formatButtonDecoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.all(Radius.circular(12.0)),
            ),
            formatButtonTextStyle: TextStyle(color: Colors.white),
          ),

          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            holidayController.setSelectedDate(selectedDay);
          },

          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },

          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            // Load holidays for the new month
            final startOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
            final endOfMonth = DateTime(
              focusedDay.year,
              focusedDay.month + 1,
              0,
            );
            holidayController.loadHolidaysForCalendar(startOfMonth, endOfMonth);
          },
        );
      }),
    );
  }

  Widget _buildHolidaysList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _selectedDay != null
                    ? 'Holidays for ${DateFormat('MMMM yyyy').format(_selectedDay!)}'
                    : 'All Holidays',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (holidayController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (holidayController.error.value.isNotEmpty) {
                  return Center(
                    child: Text(
                      'Error: ${holidayController.error.value}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final holidays = _selectedDay != null
                    ? holidayController.getHolidaysForMonth(_selectedDay!)
                    : holidayController.holidays;

                if (holidays.isEmpty) {
                  return const Center(
                    child: Text(
                      'No holidays found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: holidays.length,
                  itemBuilder: (context, index) {
                    final holiday = holidays[index];
                    return _buildHolidayCard(holiday);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayCard(Holiday holiday) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      color: holiday.markedAsLeave ? Colors.red.shade50 : Colors.white,
      child: Container(
        decoration: holiday.markedAsLeave
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200, width: 1),
              )
            : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: holiday.markedAsLeave
                ? Colors.red.shade600
                : _getHolidayTypeColor(holiday.type),
            child: Icon(
              holiday.markedAsLeave
                  ? Icons.event_busy
                  : _getHolidayTypeIcon(holiday.type),
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            holiday.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: holiday.markedAsLeave ? Colors.red.shade800 : Colors.black,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(holiday.description),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(holiday.date),
                style: TextStyle(
                  color: holiday.markedAsLeave
                      ? Colors.red.shade700
                      : Colors.indigo,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (holiday.isRecurring)
                const Text(
                  'Recurring Holiday',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (holiday.markedAsLeave)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    'MARKED AS LEAVE',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          trailing: authController.isAdmin
              ? PopupMenuButton<String>(
                  onSelected: (value) => _handleHolidayAction(value, holiday),
                  itemBuilder: (context) => [
                    if (!holiday.markedAsLeave)
                      const PopupMenuItem(
                        value: 'mark_leave',
                        child: Row(
                          children: [
                            Icon(Icons.event_busy, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Mark as Leave',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    if (holiday.markedAsLeave)
                      const PopupMenuItem(
                        value: 'unmark_leave',
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 20,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Leave Mark',
                              style: TextStyle(color: Colors.green),
                            ),
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
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Color _getHolidayTypeColor(String type) {
    switch (type) {
      case 'national':
        return Colors.red;
      case 'company':
        return Colors.indigo;
      case 'optional':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getHolidayTypeIcon(String type) {
    switch (type) {
      case 'national':
        return Icons.flag;
      case 'company':
        return Icons.business;
      case 'optional':
        return Icons.star;
      default:
        return Icons.event;
    }
  }

  void _handleHolidayAction(String action, Holiday holiday) {
    switch (action) {
      case 'mark_leave':
        _showMarkAsLeaveDialog(holiday);
        break;
      case 'unmark_leave':
        _showUnmarkLeaveDialog(holiday);
        break;
      case 'edit':
        _showEditHolidayDialog(holiday);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(holiday);
        break;
    }
  }

  void _showAddHolidayDialog() {
    _showHolidayDialog();
  }

  void _showEditHolidayDialog(Holiday holiday) {
    _showHolidayDialog(holiday: holiday);
  }

  void _showMarkAsLeaveDialog(Holiday holiday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_busy, color: Colors.red),
            SizedBox(width: 8),
            Text('Mark as Leave Day'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark "${holiday.title}" as a leave day?'),
            const SizedBox(height: 8),
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• Update the holiday calendar for all employees'),
            const Text('• Display this date with Sunday-like styling'),
            const Text('• Notify all employees about the leave day'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await holidayController.markHolidayAsLeave(
                holiday.id,
              );
              if (success) {
                Navigator.of(context).pop();
                Get.snackbar(
                  'Success',
                  'Holiday marked as leave day and all employee calendars updated',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Mark as Leave',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnmarkLeaveDialog(Holiday holiday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_available, color: Colors.green),
            SizedBox(width: 8),
            Text('Cancel Leave Mark'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove leave mark from "${holiday.title}"?'),
            const SizedBox(height: 8),
            const Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• Restore normal holiday display'),
            const Text('• Update all employee calendars'),
            const Text('• Notify employees about the change'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await holidayController.unmarkHolidayAsLeave(
                holiday.id,
              );
              if (success) {
                Navigator.of(context).pop();
                Get.snackbar(
                  'Success',
                  'Leave mark removed and all employee calendars updated',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Remove Mark',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showHolidayDialog({Holiday? holiday}) {
    final titleController = TextEditingController(text: holiday?.title ?? '');
    final descriptionController = TextEditingController(
      text: holiday?.description ?? '',
    );
    DateTime selectedDate = holiday?.date ?? _selectedDay ?? DateTime.now();
    String selectedType = holiday?.type ?? 'company';
    bool isRecurring = holiday?.isRecurring ?? false;
    bool markedAsLeave = holiday?.markedAsLeave ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(holiday == null ? 'Add Holiday' : 'Edit Holiday'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Holiday Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    'Date: ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 2),
                      ),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Holiday Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'national',
                      child: Text('National Holiday'),
                    ),
                    DropdownMenuItem(
                      value: 'company',
                      child: Text('Company Holiday'),
                    ),
                    DropdownMenuItem(
                      value: 'optional',
                      child: Text('Optional Holiday'),
                    ),
                  ],
                  onChanged: (value) => setState(() => selectedType = value!),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Recurring Holiday'),
                  value: isRecurring,
                  onChanged: (value) => setState(() => isRecurring = value!),
                ),
                CheckboxListTile(
                  title: const Row(
                    children: [
                      Icon(Icons.event_busy, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Mark as Leave Day'),
                    ],
                  ),
                  subtitle: const Text(
                    'Display with Sunday-like styling and update all employee calendars',
                  ),
                  value: markedAsLeave,
                  onChanged: (value) => setState(() => markedAsLeave = value!),
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
                if (titleController.text.trim().isEmpty) {
                  Get.snackbar('Error', 'Please enter a holiday title');
                  return;
                }

                bool success;
                if (holiday == null) {
                  success = await holidayController.addHoliday(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    date: selectedDate,
                    type: selectedType,
                    isRecurring: isRecurring,
                    markedAsLeave: markedAsLeave,
                  );
                } else {
                  success = await holidayController.updateHoliday(
                    holiday.copyWith(
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      date: selectedDate,
                      type: selectedType,
                      isRecurring: isRecurring,
                      markedAsLeave: markedAsLeave,
                    ),
                  );
                }

                if (success) {
                  Navigator.of(context).pop();
                  if (markedAsLeave) {
                    Get.snackbar(
                      'Success',
                      'Holiday ${holiday == null ? 'added' : 'updated'} and marked as leave day. All employee calendars updated.',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  }
                }
              },
              child: Text(holiday == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Holiday holiday) {
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
              final success = await holidayController.deleteHoliday(holiday.id);
              if (success) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
