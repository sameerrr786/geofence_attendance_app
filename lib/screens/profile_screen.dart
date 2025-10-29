// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofence_attendance_app/screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Get the current user from Firebase
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
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
                // Show the user's email
                currentUser?.email ?? 'No Email',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Student ID: 12345', // We'll get this from Firestore later
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const Spacer(), // Pushes the button to the bottom
            // TODO: Add "Re-register Face Profile" button here
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () {
                // TODO: Add face re-registration logic
              },
              child: const Text('Re-register Face'),
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
