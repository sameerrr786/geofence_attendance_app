// lib/screens/home_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofence_attendance_app/services/location_service.dart';
import 'package:geofence_attendance_app/screens/attendance_marking_screen.dart'; // Add this import

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
    final subject = subjectDoc.data() as Map<String, dynamic>?; // Make nullable

    // Safety Check: Ensure subject data exists
    if (subject == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: Subject data not found.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final String subjectName = subject['name'] ?? 'This Subject';

    setState(() {
      _isLoading = true;
      _loadingSubjectId = subjectDoc.id; // Set which button is loading
    });

    try {
      // 1. Get the geofence data from Firestore with safety checks
      final double? latitude = (subject['latitude'] as num?)?.toDouble();
      final double? longitude = (subject['longitude'] as num?)?.toDouble();
      // Provide a default radius if missing, or use the value from Firestore
      final double radius =
          (subject['radius'] as num?)?.toDouble() ?? 50.0; // Default 50m

      // Check if coordinates are valid
      if (latitude == null || longitude == null) {
        throw Exception('Missing location coordinates for this subject.');
      }

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
              content: Text(
                'Location confirmed for $subjectName! Proceeding to face scan...',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to Face Scan screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AttendanceMarkingScreen(subjectName: subjectName),
            ),
          );
        }
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
      // Show any other errors (like "permissions denied" or missing coordinates)
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
      if (mounted) {
        // Add mounted check here too
        setState(() {
          _isLoading = false;
          _loadingSubjectId = null;
        });
      }
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
            return Center(
              child: Text('Error fetching subjects: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No subjects found. Add subjects in Firestore.'),
            );
          }

          final subjectDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: subjectDocs.length,
            itemBuilder: (context, index) {
              final subjectDoc = subjectDocs[index];
              // Use safe casting here as well
              final subject = subjectDoc.data() as Map<String, dynamic>? ?? {};
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
                      // Use Flexible to prevent text overflow if names are long
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow
                                  .ellipsis, // Prevent long names breaking layout
                            ),
                            const SizedBox(height: 4),
                            Text(
                              instructorName,
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16), // Add spacing
                      // Show a spinner OR the button
                      if (isThisCardLoading)
                        const SizedBox(
                          // Give spinner a defined size
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      else
                        ElevatedButton(
                          // Prevent button press if already loading
                          onPressed: _isLoading
                              ? null
                              : () => _markAttendance(subjectDoc),
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
