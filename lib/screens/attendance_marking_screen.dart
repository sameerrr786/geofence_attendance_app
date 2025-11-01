import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart' // ✅ Correct import
    as tfl;
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart'; // ✅ Added for bug fix
import 'package:collection/collection.dart'; // ✅ Added for bug fix

// Access the global Supabase client instance (initialized in main.dart)
final supabase = Supabase.instance.client;

class AttendanceMarkingScreen extends StatefulWidget {
  final String subjectName;
  final int classroomId;

  const AttendanceMarkingScreen({
    super.key,
    required this.subjectName,
    required this.classroomId,
  });

  @override
  State<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  // State and Controllers
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  CameraDescription? _cameraDescription;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );

  // --- Face Recognition State ---
  tfl.Interpreter? _interpreter;
  List<double>? _registeredEmbedding; // Face embedding from user's profile
  bool _isProcessing = false;
  String _loadingMessage = "Initializing Camera...";
  bool _isModelLoaded = false;

  // Get the current Supabase User ID
  final String? userId = supabase.auth.currentUser?.id;

  // --- Model Configuration ---
  // ✅ This matches the model you downloaded
  final int _inputSize = 112;
  final int _embeddingSize = 192;
  final double _recognitionThreshold = 1.0; // Lower is stricter

  @override
  void initState() {
    super.initState();
    // Start both camera init and model loading at the same time
    _initializeCamera();
    _loadModelAndRegisteredFace();
  }

  // Initialize camera logic
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
        setState(() {
          _loadingMessage = "Error initializing camera: ${e.toString()}";
        });
      }
    }
  }

  // --- Main function to load TFLite model and user's profile face ---
  Future<void> _loadModelAndRegisteredFace() async {
    if (userId == null) {
      setState(() {
        _loadingMessage = "Error: Not logged in.";
      });
      return;
    }

    try {
      setState(() {
        _loadingMessage = "Loading recognition model...";
      });
      // 1. Load the TFLite model
      _interpreter = await tfl.Interpreter.fromAsset(
        'assets/mobilefacenet.tflite',
      );
      _interpreter!.allocateTensors();

      setState(() {
        _loadingMessage = "Fetching registered face profile...";
      });

      // 2. Fetch the user's profile to get their face image URL
      final profileResponse = await supabase
          .from('profiles')
          .select('face_image_path')
          .eq('id', userId!)
          .single();

      final imageUrl = profileResponse['face_image_path'] as String?;

      if (imageUrl == null || imageUrl.isEmpty) {
        setState(() {
          _loadingMessage =
              "Error: No face registered. Please register your face on the profile screen first.";
        });
        return;
      }

      // 3. Download the registered face image
      final http.Response imageResponse = await http.get(Uri.parse(imageUrl));
      if (imageResponse.statusCode != 200) {
        setState(() {
          _loadingMessage = "Error: Could not download profile face.";
        });
        return;
      }
      final Uint8List imageBytes = imageResponse.bodyBytes;

      // 4. Process the image and get its embedding
      // We need to detect the face in the profile image first

      // ✅ --- FIX: Use fromFilePath for more reliability ---
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/profile_face_reg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = await File(tempPath).writeAsBytes(imageBytes);

      final InputImage profileInputImage = InputImage.fromFilePath(
        tempFile.path,
      );
      // --- END FIX ---

      final List<Face> faces = await _faceDetector.processImage(
        profileInputImage,
      );

      await tempFile.delete(); // Clean up temp file

      if (faces.isEmpty) {
        setState(() {
          _loadingMessage = "Error: No face found in your profile picture.";
        });
        return;
      }

      _registeredEmbedding = await _getEmbedding(
        imageBytes,
        faces[0].boundingBox, // Crop to the detected face
      );

      setState(() {
        _isModelLoaded = true;
        _loadingMessage = ""; // Clear loading message
      });
    } catch (e) {
      print("Error loading model or face: $e");
      setState(() {
        _loadingMessage = "Error: Failed to load face recognition data.";
      });
    }
  }

  /// --- Processes an image and runs inference to get the face embedding ---
  Future<List<double>> _getEmbedding(
    Uint8List imageBytes,
    Rect boundingBox,
  ) async {
    // Decode the image
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception("Could not decode image");
    }

    // ✅ --- FIX: Crop the image to the detected bounding box ---
    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: boundingBox.left.toInt(),
      y: boundingBox.top.toInt(),
      width: boundingBox.width.toInt(),
      height: boundingBox.height.toInt(),
    );
    // --- END FIX ---

    // Resize the cropped image to the model's input size
    img.Image resizedImage = img.copyResize(
      croppedImage,
      width: _inputSize,
      height: _inputSize,
    );

    // Convert image to a Float32List of normalized pixel values
    var inputBuffer = Float32List(1 * _inputSize * _inputSize * 3);
    int bufferIndex = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        var pixel = resizedImage.getPixel(x, y);
        inputBuffer[bufferIndex++] = (pixel.r - 127.5) / 128.0;
        inputBuffer[bufferIndex++] = (pixel.g - 127.5) / 128.0;
        inputBuffer[bufferIndex++] = (pixel.b - 127.5) / 128.0;
      }
    }

    // Reshape the input to [1, 112, 112, 3]
    final input = inputBuffer.reshape([1, _inputSize, _inputSize, 3]);
    final output = List.filled(
      1 * _embeddingSize,
      0.0,
    ).reshape([1, _embeddingSize]);

    // Run inference
    _interpreter!.run(input, output);

    // Return the embedding (a 1D list)
    return List<double>.from(output[0]);
  }

  /// --- Calculates the L2 (Euclidean) distance between two embeddings ---
  double _calculateDistance(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) {
      throw Exception("Embeddings have different lengths");
    }
    double sum = 0;
    for (int i = 0; i < emb1.length; i++) {
      sum += math.pow(emb1[i] - emb2[i], 2);
    }
    return math.sqrt(sum);
  }

  // --- LOGIC MODIFIED: Scan, Compare, Upload, and Log Status ---
  Future<void> _scanFaceAndLogAttendance() async {
    if (userId == null) {
      _showSnackbar('User not logged in.', isError: true);
      return;
    }
    // Check if camera is ready AND model/profile face are loaded
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !_isModelLoaded ||
        _registeredEmbedding == null ||
        _isProcessing) {
      if (!_isModelLoaded) {
        _showSnackbar(
          'Recognition model not ready. Please wait.',
          isError: true,
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Take a picture
      final XFile imageFile = await _cameraController!.takePicture();

      // ✅ --- FIX: Create correct metadata for camera image ---
      final imageBytes = await File(imageFile.path).readAsBytes();
      final image = await decodeImageFromList(imageBytes);

      // Get temporary directory to save file for InputImage.fromFilePath
      // This is more reliable for MLKit than fromBytes
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = await File(tempPath).writeAsBytes(imageBytes);

      // Create metadata for the saved file
      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg, // Adjust if needed
        format: InputImageFormat.nv21, // Common Android format
        bytesPerRow: image.width, // Guessing bytes per row
      );
      // --- END FIX ---

      final InputImage inputImage = InputImage.fromFilePath(tempFile.path);

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      await tempFile.delete(); // Clean up the temp file

      if (faces.isEmpty) {
        _showSnackbar(
          'No face detected. Please look at the camera.',
          isError: true,
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // 2. Get embedding from the new camera image
      final List<double> currentEmbedding = await _getEmbedding(
        imageBytes,
        faces[0].boundingBox, // Crop to the detected face
      );

      // 3. Compare the new embedding with the registered one
      final double distance = _calculateDistance(
        _registeredEmbedding!,
        currentEmbedding,
      );

      String status;
      String message;
      bool isMatch = distance < _recognitionThreshold;

      if (isMatch) {
        status = 'PRESENT';
        message = 'Face matched! Attendance marked as PRESENT.';
      } else {
        status = 'FAILED';
        message =
            'Face mismatch (distance: ${distance.toStringAsFixed(2)}). Attendance FAILED.';
      }

      // 4. Upload image to Supabase Storage (for auditing)
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/attendance/$fileName';

      await supabase.storage
          .from('user_face_images') // Your bucket name
          .uploadBinary(
            filePath,
            imageBytes, // Use the bytes we already have
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      // Get the public URL to store in the database
      final String downloadUrl = supabase.storage
          .from('user_face_images')
          .getPublicUrl(filePath);

      // 5. Log attendance in Supabase 'attendance' table with the new status
      await supabase.from('attendance').insert({
        'user_id': userId,
        'classroom_id': widget.classroomId,
        'image_url': downloadUrl,
        'status': status, // Use the calculated status
      });

      _showSnackbar(
        message,
        isError: !isMatch, // Show red snackbar if mismatch
      );
      if (mounted) {
        Navigator.of(context).pop(); // Go back to dashboard
      }
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
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Show loading messages while camera and model are initializing
    if (!_isCameraInitialized ||
        !_isModelLoaded ||
        _loadingMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mark Attendance for ${widget.subjectName}'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _loadingMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Camera error screen
    if (_cameraController?.value.hasError ?? true) {
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

    // Main camera view
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
