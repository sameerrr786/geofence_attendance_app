// lib/screens/face_registration_screen.dart
import 'package:flutter/material.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  // TODO: Add Camera and Face Detection logic here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Your Face')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Camera View Will Appear Here'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // TODO: Capture image and process face
                Navigator.of(context).pop(); // Go back for now
              },
              child: const Text('Capture & Save Face'),
            ),
          ],
        ),
      ),
    );
  }
}
