import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/holiday_controller.dart';
import '../theme/app_theme.dart';

class AttendanceStatisticsWidget extends StatelessWidget {
  final bool showPieChart;
  final bool isCompact;

  const AttendanceStatisticsWidget({
    super.key,
    this.showPieChart = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceController = Get.find<AttendanceController>();
    final holidayController = Get.find<HolidayController>();

    return Obx(() {
      final stats = _calculateStatistics(
        attendanceController,
        holidayController,
      );

      return Container(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.primaryColor,
                  size: isCompact ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attendance Overview',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This Month',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 12 : 16),

            if (showPieChart && !isCompact) ...[
              Row(
                children: [
                  // Pie Chart
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(stats),
                              centerSpaceRadius: 50,
                              sectionsSpace: 2,
                              startDegreeOffset: -90,
                            ),
                          ),
                          // Center text
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${stats['totalDays']}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const Text(
                                  'Total Days',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Legend
                  Expanded(flex: 1, child: _buildLegend(stats)),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Statistics Grid
            _buildStatisticsGrid(stats, isCompact),

            if (!isCompact) ...[
              const SizedBox(height: 16),
              _buildAttendanceRate(stats),
            ],
          ],
        ),
      );
    });
  }

  Map<String, int> _calculateStatistics(
    AttendanceController attendanceController,
    HolidayController holidayController,
  ) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // Get total working days in month (excluding weekends)
    int totalWorkingDays = 0;
    for (
      DateTime date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        totalWorkingDays++;
      }
    }

    // Get company holidays marked as leave
    final holidays = holidayController.holidays
        .where(
          (holiday) =>
              holiday.date.month == now.month &&
              holiday.date.year == now.year &&
              holiday.markedAsLeave == true,
        )
        .length;

    // Calculate actual working days after removing company holidays
    final actualWorkingDays = totalWorkingDays - holidays;

    // Simulate more realistic data for demonstration
    final totalEmployees = attendanceController.totalEmployees.value > 0
        ? attendanceController.totalEmployees.value
        : 1;

    final presentDays = (totalEmployees * actualWorkingDays * 0.85).round();
    final wfhDays = (totalEmployees * actualWorkingDays * 0.10).round();
    final leaveDays = (totalEmployees * actualWorkingDays * 0.03).round();
    final absentDays = (totalEmployees * actualWorkingDays * 0.02).round();

    return {
      'present': presentDays,
      'absent': absentDays,
      'wfh': wfhDays,
      'leave': leaveDays,
      'holidays': holidays,
      'totalDays': totalWorkingDays,
      'companyHolidays': holidays,
    };
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> stats) {
    final total = stats['totalDays']! > 0 ? stats['totalDays']! : 1;

    return [
      // Present
      PieChartSectionData(
        color: const Color(0xFF4CAF50), // Material Green 500
        value: (stats['present']! / total * 100),
        title: '${(stats['present']! / total * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      // Work from Home
      PieChartSectionData(
        color: const Color(0xFF2196F3), // Material Blue 500
        value: (stats['wfh']! / total * 100),
        title: '${(stats['wfh']! / total * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      // On Leave
      PieChartSectionData(
        color: const Color(0xFFF44336), // Material Red 500 - changed to red
        value: (stats['leave']! / total * 100),
        title: '${(stats['leave']! / total * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      // Absent
      PieChartSectionData(
        color: const Color(
          0xFF795548,
        ), // Material Brown 500 - changed from red to brown since leave is now red
        value: (stats['absent']! / total * 100),
        title: '${(stats['absent']! / total * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      // Company Holidays
      PieChartSectionData(
        color: const Color(0xFF9C27B0), // Material Purple 500
        value: (stats['companyHolidays']! / total * 100),
        title:
            '${(stats['companyHolidays']! / total * 100).toStringAsFixed(1)}%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildLegend(Map<String, int> stats) {
    final legendItems = [
      {
        'label': 'Present',
        'color': const Color(0xFF4CAF50),
        'value': stats['present']!,
      },
      {
        'label': 'WFH',
        'color': const Color(0xFF2196F3),
        'value': stats['wfh']!,
      },
      {
        'label': 'On Leave',
        'color': const Color(0xFFF44336), // Red
        'value': stats['leave']!,
      },
      {
        'label': 'Absent',
        'color': const Color(0xFF795548), // Brown
        'value': stats['absent']!,
      },
      {
        'label': 'Company\nHolidays',
        'color': const Color(0xFF9C27B0),
        'value': stats['companyHolidays']!,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: legendItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${item['value']} days',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatisticsGrid(Map<String, int> stats, bool isCompact) {
    final gridItems = [
      {
        'title': 'Present',
        'value': '${stats['present']}',
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50), // Material Green 500
        'subtitle': 'days this month',
      },
      {
        'title': 'Work from Home',
        'value': '${stats['wfh']}',
        'icon': Icons.home_work,
        'color': const Color(0xFF2196F3), // Material Blue 500
        'subtitle': 'WFH days',
      },
      {
        'title': 'On Leave',
        'value': '${stats['leave']}',
        'icon': Icons.event_busy,
        'color': const Color(0xFFF44336), // Red
        'subtitle': 'leave days',
      },
      {
        'title': 'Absent',
        'value': '${stats['absent']}',
        'icon': Icons.cancel,
        'color': const Color(0xFF795548), // Brown
        'subtitle': 'absent days',
      },
      {
        'title': 'Company Holidays',
        'value': '${stats['companyHolidays']}',
        'icon': Icons.event_available,
        'color': const Color(0xFF9C27B0), // Material Purple 500
        'subtitle': 'holiday days',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 2 : 4,
        childAspectRatio: isCompact ? 1.2 : 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gridItems.length,
      itemBuilder: (context, index) {
        final item = gridItems[index];
        return _buildStatCard(
          item['title'] as String,
          item['value'] as String,
          item['icon'] as IconData,
          item['color'] as Color,
          item['subtitle'] as String,
          isCompact,
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    bool isCompact,
  ) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isCompact ? 20 : 24),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isCompact) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceRate(Map<String, int> stats) {
    final totalWorkingDays = stats['totalDays']! - stats['companyHolidays']!;
    final attendedDays = stats['present']! + stats['wfh']! + stats['leave']!;
    final attendanceRate = totalWorkingDays > 0
        ? (attendedDays / totalWorkingDays * 100)
        : 0.0;

    Color rateColor;
    String rateText;

    if (attendanceRate >= 95) {
      rateColor = const Color(0xFF4CAF50); // Material Green 500
      rateText = 'Excellent';
    } else if (attendanceRate >= 85) {
      rateColor = const Color(0xFF2196F3); // Material Blue 500
      rateText = 'Good';
    } else if (attendanceRate >= 75) {
      rateColor = const Color(0xFFFF9800); // Material Orange 500
      rateText = 'Average';
    } else {
      rateColor = const Color(0xFFF44336); // Material Red 500
      rateText = 'Poor';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [rateColor.withOpacity(0.1), rateColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rateColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rateColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              attendanceRate >= 85 ? Icons.trending_up : Icons.trending_down,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Attendance Rate',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${attendanceRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: rateColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: rateColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        rateText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$attendedDays/$totalWorkingDays',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: rateColor,
                ),
              ),
              const Text(
                'attended days',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
