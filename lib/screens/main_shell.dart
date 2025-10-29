import 'package:flutter/material.dart';
import 'package:geofence_attendance_app/screens/attendance_history_screen.dart';
import 'package:geofence_attendance_app/screens/home_dashboard_screen.dart';
import 'package:geofence_attendance_app/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // This variable tracks which tab is currently selected
  int _selectedIndex = 0;

  // This list holds the screens that the nav bar will switch between
  static const List<Widget> _screens = <Widget>[
    HomeDashboardScreen(), // Index 0
    AttendanceHistoryScreen(), // Index 1
    ProfileScreen(), // Index 2
  ];

  // This function updates the state when a tab is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body of our app is just the currently selected screen
      body: _screens.elementAt(_selectedIndex),

      // The Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex, // Highlights the current tab
        selectedItemColor: Colors.deepPurple, // Color of the active tab
        onTap: _onItemTapped, // Function to call when tapped
      ),
    );
  }
}
