import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';

class EmployeeLocationScreen extends StatefulWidget {
  const EmployeeLocationScreen({super.key});

  @override
  State<EmployeeLocationScreen> createState() => _EmployeeLocationScreenState();
}

class _EmployeeLocationScreenState extends State<EmployeeLocationScreen> {
  final AuthController authController = Get.find<AuthController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Locations'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildLocationList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real-time Employee Locations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View current location and check-in status of your employees',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationList() {
    final companyId = authController.currentCompany.value?.id;

    if (companyId == null) {
      return const Center(child: Text('No company data available'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('employee_location_tracking')
          .where('companyId', isEqualTo: companyId)
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final locations = snapshot.data?.docs ?? [];

        if (locations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No employee location data available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final locationData =
                locations[index].data() as Map<String, dynamic>;
            return _buildLocationCard(locationData);
          },
        );
      },
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> data) {
    final isOnDuty = data['isOnDuty'] ?? false;
    final userName = data['userName'] ?? 'Unknown Employee';
    final currentLocation = data['currentLocation'] ?? 'Location not available';
    final lastUpdated = data['lastUpdated'] as Timestamp?;
    final lastCheckIn = data['lastCheckIn'] as Timestamp?;
    final status = data['status'] ?? 'offline';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isOnDuty
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isOnDuty ? Colors.green : Colors.grey,
                radius: 20,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isOnDuty ? Icons.work : Icons.work_off,
                          size: 16,
                          color: isOnDuty ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnDuty ? 'On Duty' : 'Off Duty',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOnDuty ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  currentLocation,
                  style: const TextStyle(fontSize: 13, color: Colors.blue),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (lastCheckIn != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Checked in: ${DateFormat('MMM dd, hh:mm a').format(lastCheckIn.toDate())}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ],
          if (lastUpdated != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.update, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Last updated: ${DateFormat('MMM dd, hh:mm a').format(lastUpdated.toDate())}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
          if (data['latitude'] != null && data['longitude'] != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLocationOnMap(
                  data['latitude'],
                  data['longitude'],
                  userName,
                ),
                icon: const Icon(Icons.map, size: 16),
                label: const Text('View on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'checked_in':
        return Colors.green;
      case 'on_duty':
        return Colors.blue;
      case 'offline':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  void _showLocationOnMap(double lat, double lng, String employeeName) {
    Get.dialog(
      AlertDialog(
        title: Text('$employeeName Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text('Latitude: ${lat.toStringAsFixed(6)}'),
            Text('Longitude: ${lng.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            const Text(
              'In a full implementation, this would open a map view showing the employee location.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }
}
