import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting

// Access the global Supabase client
final supabase = Supabase.instance.client;

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late final Future<List<Map<String, dynamic>>> _historyFuture;
  final String? _userId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    // Initialize the future to fetch data when the screen loads
    _historyFuture = _fetchAttendanceHistory();
  }

  /// Fetches attendance records joined with classroom names for the current user.
  Future<List<Map<String, dynamic>>> _fetchAttendanceHistory() async {
    if (_userId == null) {
      throw Exception("User not logged in.");
    }

    try {
      final response = await supabase
          .from('attendance')
          .select('''
            marked_at,
            status,
            classrooms (
              name 
            )
          ''') // ✅ --- MODIFIED THIS LINE ---
          // Assumes your column is 'name'.
          // If it's 'subject', change 'name' to 'subject'.
          .eq('user_id', _userId)
          .order('marked_at', ascending: false); // Show newest first

      // Note: The 'response' here is a List<dynamic>,
      // so we need to cast it correctly.
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Handle potential errors (like RLS being off, network issues)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to fetch history: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return []; // Return an empty list on error
    }
  }

  /// Helper to get a color based on the attendance status
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PRESENT':
        return Colors.green;
      case 'ABSENT':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance History'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      // Use a FutureBuilder to display data once it's loaded
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          // --- 1. Loading State ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- 2. Error State ---
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching history: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          // --- 3. Empty State ---
          final historyRecords = snapshot.data;
          if (historyRecords == null || historyRecords.isEmpty) {
            return const Center(
              child: Text(
                'No attendance history found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // --- 4. Success State (Display the list) ---
          return ListView.builder(
            itemCount: historyRecords.length,
            itemBuilder: (context, index) {
              final record = historyRecords[index];
              final classroomData = record['classrooms'];

              // Handle cases where the classroom might have been deleted
              // ✅ --- MODIFIED THIS LINE ---
              final subjectName = classroomData?['name'] ?? 'Unknown Subject';
              final status = (record['status'] as String? ?? 'N/A')
                  .toUpperCase();

              // Format the timestamp
              final markedAt = DateTime.parse(record['marked_at']).toLocal();
              final formattedDate = DateFormat.yMd().add_jm().format(markedAt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(formattedDate),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
