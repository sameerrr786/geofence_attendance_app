import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ CHANGED
import 'package:geofence_attendance_app/screens/login_screen.dart';
import 'package:geofence_attendance_app/screens/face_registration_screen.dart';

// Access the global Supabase client
final supabase = Supabase.instance.client;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Get the current user from Supabase
  User? get currentUser => supabase.auth.currentUser;

  Future<void> _logout(BuildContext context) async {
    await supabase.auth.signOut(); // ✅ CHANGED
    // Navigate back to LoginScreen and remove all other pages
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple.withAlpha(100),
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                // ✅ Show the user's email from Supabase
                currentUser?.email ?? 'No Email',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                // We'll get this from the 'profiles' table later
                'Student ID: 12345',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const Spacer(),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FaceRegistrationScreen(),
                  ),
                );
              },
              child: const Text('Register / Update Face'),
            ),
            const SizedBox(height: 16),

            // Logout Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _logout(context),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
