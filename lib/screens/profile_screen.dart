import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geofence_attendance_app/screens/login_screen.dart';
import 'package:geofence_attendance_app/screens/face_registration_screen.dart';

// Access the global Supabase client
final supabase = Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get currentUser => supabase.auth.currentUser;

  // Stream is nullable because the user might not be logged in immediately
  Stream<Map<String, dynamic>?>? _profileStream;

  @override
  void initState() {
    super.initState();
    // CRITICAL FIX: Only initialize the stream if the user is logged in
    if (currentUser != null) {
      _profileStream = supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', currentUser!.id)
          .map((list) => list.isNotEmpty ? list.first : null);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- Widget for the data-driven content (User Info, Profile, ID) ---
  Widget _buildProfileContent(
    BuildContext context,
    Map<String, dynamic>? profileData,
  ) {
    // If profileData is null, show the base 'Profile not found' fallback
    if (profileData == null) {
      return Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.withAlpha(100),
            child: const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              currentUser?.email ?? 'No Email',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Status: Profile Not Yet Created',
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );
    }

    // --- Success State ---
    final imageUrl = profileData['face_image_path'] as String?;
    // Assumes your student ID column is 'student_id'
    final studentId = profileData['student_id'] as String? ?? 'Not Set';

    // --- Data-driven UI ---
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.deepPurple.withAlpha(100),
          // Display network image if URL exists
          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
              ? NetworkImage(imageUrl)
              : null,
          // Show icon as a fallback if no image
          child: (imageUrl == null || imageUrl.isEmpty)
              ? const Icon(Icons.person, size: 50, color: Colors.deepPurple)
              : null,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            currentUser?.email ?? 'No Email',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Student ID: $studentId',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error if user data is missing entirely
    if (currentUser == null) {
      return const Center(child: Text("Please log in to view your profile."));
    }

    // CRITICAL: If _profileStream hasn't been initialized (due to the safety check), show loading
    if (_profileStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
            // Use a StreamBuilder to display profile data
            StreamBuilder<Map<String, dynamic>?>(
              stream: _profileStream,
              builder: (context, snapshot) {
                // --- 1. Loading State ---
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // --- 2. Error State ---
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error fetching data: ${snapshot.error}'),
                  );
                }

                // --- 3. Success or No Data State ---
                return _buildProfileContent(context, snapshot.data);
              },
            ),

            const Spacer(),

            // This section is outside the StreamBuilder to remain visible
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
