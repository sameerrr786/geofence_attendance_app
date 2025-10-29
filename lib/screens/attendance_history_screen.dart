import 'package:flutter/material.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance History'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: const Center(child: Text('This is the History Page')),
    );
  }
}
