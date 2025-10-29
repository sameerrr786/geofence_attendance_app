// lib/screens/home_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofence_attendance_app/services/location_service.dart'; // Import our new service

// Convert to a StatefulWidget to manage loading state
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false; // Manages the loading spinner
  String? _loadingSubjectId; // Tracks WHICH subject is being marked

  /// This is our new function to handle the attendance button press
  Future<void> _markAttendance(DocumentSnapshot subjectDoc) async {
    final subject = subjectDoc.data() as Map<String, dynamic>;
    final String subjectName = subject['name'] ?? 'This Subject';

    setState(() {
      _isLoading = true;
      _loadingSubjectId = subjectDoc.id; // Set which button is loading
    });

    try {
      // 1. Get the geofence data from Firestore
      final double latitude = subject['latitude'];
      final double longitude = subject['longitude'];
      final double radius = subject['radius']
          .toDouble(); // Ensure it's a double

      // 2. Call our location service
      final bool isInside = await _locationService.isWithinGeofence(
        classLat: latitude,
        classLng: longitude,
        radius: radius,
      );

      // 3. Show success or error based on location
      if (isInside) {
        // SUCCESS!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location confirmed for $subjectName!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // TODO: Navigate to Face Scan screen
      } else {
        // FAILURE!
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You are not inside the classroom!'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      // Show any other errors (like "permissions denied")
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // 4. Stop the loading spinner
      setState(() {
        _isLoading = false;
        _loadingSubjectId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subjects'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No subjects found.'));
          }

          final subjectDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: subjectDocs.length,
            itemBuilder: (context, index) {
              final subjectDoc = subjectDocs[index];
              final subject = subjectDoc.data() as Map<String, dynamic>;
              final String subjectName = subject['name'] ?? 'No Name';
              final String instructorName =
                  subject['instructor'] ?? 'No Instructor';

              // Check if this specific card is the one loading
              final bool isThisCardLoading =
                  _isLoading && _loadingSubjectId == subjectDoc.id;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subjectName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            instructorName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      // Show a spinner OR the button
                      if (isThisCardLoading)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: () => _markAttendance(subjectDoc),
                          child: const Text('Mark'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
