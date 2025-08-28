import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../controllers/holiday_controller.dart';
import '../models/holiday_model.dart';

class SharedCalendarWidget extends StatefulWidget {
  final Function(DateTime)? onDateSelected;
  final bool showHolidayDetails;
  final bool readOnly;

  const SharedCalendarWidget({
    super.key,
    this.onDateSelected,
    this.showHolidayDetails = true,
    this.readOnly = false,
  });

  @override
  State<SharedCalendarWidget> createState() => _SharedCalendarWidgetState();
}

class _SharedCalendarWidgetState extends State<SharedCalendarWidget> {
  final HolidayController holidayController = Get.put(HolidayController());
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    // Load holidays for current month
    _loadHolidaysForCurrentView();
  }

  void _loadHolidaysForCurrentView() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    holidayController.loadHolidaysForCalendar(startOfMonth, endOfMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          _buildCalendar(),
          if (widget.showHolidayDetails) _buildSelectedDateHolidays(),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Obx(() {
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
          markersMaxCount: 3,
          markerDecoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          // Highlight holidays with special styling
          holidayDecoration: BoxDecoration(
            color: Colors.red.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
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

        // Holiday determination
        holidayPredicate: (day) {
          return holidayController.getEventsForDay(day).isNotEmpty;
        },

        onDaySelected: widget.readOnly
            ? null
            : (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                holidayController.setSelectedDate(selectedDay);
                widget.onDateSelected?.call(selectedDay);
              },

        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },

        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
          _loadHolidaysForCurrentView();
        },
      );
    });
  }

  Widget _buildSelectedDateHolidays() {
    if (_selectedDay == null) return const SizedBox.shrink();

    return Obx(() {
      final holidays = holidayController.getEventsForDay(_selectedDay!);

      if (holidays.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No holidays on ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Holidays on ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
            ...holidays.map((holiday) => _buildHolidayItem(holiday)),
          ],
        ),
      );
    });
  }

  Widget _buildHolidayItem(Holiday holiday) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getHolidayTypeColor(holiday.type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getHolidayTypeColor(holiday.type).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getHolidayTypeIcon(holiday.type),
            color: _getHolidayTypeColor(holiday.type),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (holiday.description.isNotEmpty)
                  Text(
                    holiday.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                Text(
                  _getHolidayTypeDisplayName(holiday.type),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getHolidayTypeColor(holiday.type),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  String _getHolidayTypeDisplayName(String type) {
    switch (type) {
      case 'national':
        return 'National Holiday';
      case 'company':
        return 'Company Holiday';
      case 'optional':
        return 'Optional Holiday';
      default:
        return 'Holiday';
    }
  }
}
