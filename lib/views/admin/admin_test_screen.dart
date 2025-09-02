import 'package:flutter/material.dart';
import '../../services/admin_setup_service.dart';

class AdminTestScreen extends StatelessWidget {
  const AdminTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Admin Creation Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Method 1: Create Default Admin
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    print('🔵 Starting default admin creation...');

                    final success =
                        await AdminSetupService.createDefaultAdmin();

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Default Admin Created!\nEmail: admin@company.com\nPassword: Admin123!',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Failed to create admin'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    print('🔴 Error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Default Admin'),
              ),
            ),

            const SizedBox(height: 20),

            // Method 2: Create Custom Admin
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    print('🔵 Starting custom admin creation...');

                    final success = await AdminSetupService.createAdminUser(
                      email: 'myadmin@test.com',
                      password: 'MyPassword123!',
                      name: 'My Admin',
                      phone: '+1234567890',
                      companyName: 'My Company',
                    );

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Custom Admin Created!\nEmail: myadmin@test.com\nPassword: MyPassword123!',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Failed to create custom admin'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    print('🔴 Error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Custom Admin'),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. Tap "Create Default Admin" to create:\n'
              '   Email: admin@company.com\n'
              '   Password: Admin123!\n\n'
              '2. Or tap "Create Custom Admin" to create:\n'
              '   Email: myadmin@test.com\n'
              '   Password: MyPassword123!\n\n'
              '3. Check the console/debug output for details\n'
              '4. After creation, go back and login',
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}
