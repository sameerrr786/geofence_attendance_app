// lib/main.dart
import 'package:flutter/material.dart';
import 'package:geofence_attendance_app/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase SDK

// 🚨 1. YOUR SUPABASE CREDENTIALS 🚨
// Replace these placeholders with the actual Project URL and Anon Key
// copied from your Supabase Dashboard -> Settings -> API.
const String SUPABASE_URL = 'https://oebnzszkiudxevikvhsu.supabase.co';
const String SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lYm56c3praXVkeGV2aWt2aHN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4MjAzMDksImV4cCI6MjA3NzM5NjMwOX0.ewMzzRucR2xEyrl7dX12QVxhu6RKfjf7SJUXbZhDvTE';

// 2. Main Initialization Function
Future<void> main() async {
  // Ensure Flutter binding is initialized before calling platform-specific code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase services (Auth, Database, Storage)
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    // Optional: Add custom local storage for Web/Desktop if needed
    // localStorage: const SupabaseLocalStorage(),
  );

  runApp(const MyApp());
}

// 3. Global Supabase Client Reference
// Use this variable throughout your app (e.g., supabase.from('table').select())
final supabase = Supabase.instance.client;

// 4. MyApp Class (Unchanged structure)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
          titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.deepPurple.withAlpha(50),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
