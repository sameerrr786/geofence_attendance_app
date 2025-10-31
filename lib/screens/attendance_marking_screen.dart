import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ ADDED

// Access the global Supabase client instance (initialized in main.dart)
final supabase = Supabase.instance.client;

class AttendanceMarkingScreen extends StatefulWidget {
  final String subjectName;
  final int classroomId; // ✅ ADDED: To link the record

  const AttendanceMarkingScreen({
    super.key,
    required this.subjectName,
    required this.classroomId, // ✅ ADDED
  });

  @override
  State<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  // State and Controllers (as before)
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  CameraDescription? _cameraDescription;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  bool _isProcessing = false;

  // ✅ Get the current Supabase User ID
  final String? userId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Initialize camera logic (unchanged)
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraDescription = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      _cameraDescription!,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize camera: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // --- ✅ MIGRATED CORE LOGIC: Scan, Upload to Supabase, and Log ---
  Future<void> _scanFaceAndLogAttendance() async {
    if (userId == null) {
      _showSnackbar('User not logged in.', isError: true);
      return;
    }
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Take a picture and detect face (unchanged)
      final XFile imageFile = await _cameraController!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _showSnackbar(
          'No face detected. Please look at the camera.',
          isError: true,
        );
        return;
      }

      // Face Detected! Proceed with logging and upload.

      // 2. Upload image to Supabase Storage
      final fileBytes = await File(imageFile.path).readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      // Path format: {user_id}/attendance/{filename}
      final filePath = '$userId/attendance/$fileName';

      await supabase.storage
          .from('user_face_images') // Your bucket name
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false, // Don't overwrite
            ),
          );

      // Get the public URL to store in the database
      final String downloadUrl = supabase.storage
          .from('user_face_images')
          .getPublicUrl(filePath);

      // 3. Log attendance in Supabase 'attendance' table
      await supabase.from('attendance').insert({
        'user_id': userId,
        'classroom_id': widget.classroomId,
        'image_url': downloadUrl,
        'status':
            'PENDING', // This will be the default from the DB, but good to be explicit
        // 'marked_at' will be set to now() by default in the database
      });

      _showSnackbar(
        'Attendance submitted for verification (PENDING).',
        isError: false,
      );
      Navigator.of(context).pop(); // Go back to dashboard
    } on StorageException catch (e) {
      print("Storage Error during attendance submission: $e");
      _showSnackbar('Storage Submission failed: ${e.message}', isError: true);
    } catch (e) {
      print("Error during attendance submission: $e");
      _showSnackbar('Submission failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (Your build method is unchanged) ...
    if (!_isCameraInitialized &&
        !(_cameraController?.value.hasError ?? false)) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Initializing Camera..."),
            ],
          ),
        ),
      );
    }

    if (!(_cameraController?.value.isInitialized ?? false)) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mark Attendance for ${widget.subjectName}'),
        ),
        body: const Center(
          child: Text(
            "Camera Error: Access denied or failed to load.",
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Mark Attendance for ${widget.subjectName}')),
      body: Column(
        children: [
          Expanded(child: Center(child: CameraPreview(_cameraController!))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _scanFaceAndLogAttendance,
              child: _isProcessing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Scan Face & Mark Present'),
            ),
          ),
        ],
      ),
    );
  }
}
