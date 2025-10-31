// lib/screens/attendance_marking_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart'; // Still needed for InputImage and Face

// --- The helper function _inputImageFromCameraImage has been REMOVED ---

class AttendanceMarkingScreen extends StatefulWidget {
  final String subjectName;

  const AttendanceMarkingScreen({super.key, required this.subjectName});

  @override
  State<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  CameraDescription? _cameraDescription; // Store the camera description
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  bool _isProcessing = false; // Prevent multiple scans at once

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

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
            content: Text('Error initializing camera: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // --- Face Detection Logic ---
  Future<void> _scanFace() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Take a picture
      final XFile imageFile = await _cameraController!.takePicture();
      // 2. Create InputImage directly from file path (Correct approach)
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);

      // 3. Process the image for faces
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      // 4. Check if any face was detected
      if (faces.isNotEmpty) {
        print("Face detected!");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face Detected! Marking attendance...'),
              backgroundColor: Colors.green,
            ),
          );
          // TODO: Implement Face Recognition & save attendance record
          Navigator.of(context).pop();
        }
      } else {
        print("No face detected.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No face detected. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      print("Error scanning face: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning face: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // Ensure state is updated only if the widget is still mounted
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // It's safer to dispose the controller before closing the detector
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle the case where camera description might be null initially
    final cameraDescription = _cameraDescription;

    return Scaffold(
      appBar: AppBar(title: Text('Mark Attendance for ${widget.subjectName}')),
      body: Column(
        children: [
          Expanded(
            // Check _cameraController?.value.isInitialized for safety
            child:
                _isCameraInitialized &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized
                ? Center(
                    child: CameraPreview(_cameraController!),
                    // Using CameraPreview directly might handle aspect ratio better sometimes
                    // Consider adding AspectRatio if needed:
                    // AspectRatio(
                    //   aspectRatio: _cameraController!.value.aspectRatio,
                    //   child: CameraPreview(_cameraController!),
                    // ),
                  )
                : const Center(
                    child: Column(
                      // Improved loading indicator
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Initializing Camera..."),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed:
                  (_isCameraInitialized &&
                      !_isProcessing &&
                      _cameraController != null &&
                      _cameraController!.value.isInitialized)
                  ? _scanFace
                  : null,
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
