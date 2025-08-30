import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/location_controller.dart';
import '../controllers/attendance_controller.dart';
import '../theme/app_theme.dart';

class LocationAttendanceWidget extends StatelessWidget {
  const LocationAttendanceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final locationController = Get.put(LocationController());
    final attendanceController = Get.put(AttendanceController());

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Header
            Row(
              children: [
                Icon(Icons.location_on, color: AppTheme.primaryColor, size: 24),
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

            // Location Display
            Obx(() {
              if (locationController.isLoading.value) {
                return const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Getting location...'),
                  ],
                );
              }

              if (locationController.currentAddress.value.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location not available. Please enable location permissions.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationController.currentAddress.value,
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Map Container
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/map_placeholder.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Map Preview',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Attendance Actions
            Row(
              children: [
                Expanded(
                  child: Obx(() {
                    final hasCheckedIn =
                        attendanceController.hasCheckedInToday.value;
                    final isLoading = attendanceController.isLoading.value;

                    return ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (hasCheckedIn) {
                                await attendanceController.checkOut();
                              } else {
                                await attendanceController.checkIn();
                              }
                              // Update location after check-in/out
                              if (!hasCheckedIn) {
                                await attendanceController
                                    .updateCurrentLocation();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCheckedIn
                            ? Colors.red[400]
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hasCheckedIn ? Icons.logout : Icons.login,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasCheckedIn ? 'Check Out' : 'Check In',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Last Activity
            Obx(() {
              final lastActivity = attendanceController.lastActivity.value;
              if (lastActivity.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastActivity,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
