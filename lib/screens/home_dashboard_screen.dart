import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geofence_attendance_app/services/location_service.dart';
import 'package:geofence_attendance_app/screens/attendance_marking_screen.dart';

// Access the global Supabase client instance (initialized in main.dart)
final supabase = Supabase.instance.client;

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final LocationService _locationService = LocationService();

  bool _isLoading = false;
  int? _loadingSubjectId;

  late final Future<List<Map<String, dynamic>>> _classroomsFuture;

  @override
  void initState() {
    super.initState();
    _classroomsFuture = _fetchClassrooms();
  }

  Future<List<Map<String, dynamic>>> _fetchClassrooms() async {
    try {
      // This query selects all columns (*) from 'classrooms',
      // which will include your new 'altitude' column.
      // It also joins the 'full_name' from the 'profiles' table.
      final data = await supabase
          .from('classrooms')
          .select('*, profiles(full_name)');

      return data;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch classrooms: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return []; // Return an empty list on error
    }
  }

  Future<void> _markAttendance(Map<String, dynamic> classroom) async {
    final String subjectName = classroom['name'] ?? 'This Subject';

    setState(() {
      _isLoading = true;
      _loadingSubjectId = classroom['id'];
    });

    try {
      // 1. Get the geofence data from the map
      final double? latitude = (classroom['latitude'] as num?)?.toDouble();
      final double? longitude = (classroom['longitude'] as num?)?.toDouble();
      // ✅ --- NEW: Get the altitude ---
      final double? altitude = (classroom['altitude'] as num?)?.toDouble();

      // Use 'radius_m' and provide a default
      // This radius will be passed to location_service and override its default.
      final double radius = (classroom['radius_m'] as num?)?.toDouble() ?? 50.0;

      // ✅ --- NEW: Check for altitude ---
      if (latitude == null || longitude == null || altitude == null) {
        throw Exception(
          'Missing location or altitude coordinates for this subject. Please ask your admin to update them.',
        );
      }

      // 2. Call our location service, now with altitude
      final bool isInside = await _locationService.isWithinGeofence(
        classLat: latitude,
        classLng: longitude,
        classAltitude: altitude, // ✅ --- ADDED ALTITUDE ---
        radius: radius,
      );

      // 3. Show success or error
      if (isInside) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location confirmed for $subjectName! Proceeding to face scan...',
              ),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AttendanceMarkingScreen(
                subjectName: subjectName,
                classroomId: classroom['id'],
              ),
            ),
          );
        }
      }
      // Note: isWithinGeofence will now throw its own errors for
      // "wrong floor" or "too far", which will be caught below.
    } catch (e) {
      // This will now catch errors from isWithinGeofence,
      // like "You are on the wrong floor."
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
      // ✅ CHANGED: Removed the stray "LAG" text
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _classroomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error fetching subjects: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No classrooms found. Add subjects in Supabase.'),
            );
          }

          final classrooms = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: classrooms.length,
            itemBuilder: (context, index) {
              final classroom = classrooms[index];
              final String subjectName = classroom['name'] ?? 'No Name';

              final String instructorName;
              if (classroom['profiles'] != null) {
                instructorName =
                    classroom['profiles']['full_name'] ?? 'No Instructor';
              } else {
                instructorName = 'No Instructor';
              }

              final bool isThisCardLoading =
                  _isLoading && _loadingSubjectId == classroom['id'];

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
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(width: 16),
                      if (isThisCardLoading)
                        const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      else
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _markAttendance(classroom),
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
