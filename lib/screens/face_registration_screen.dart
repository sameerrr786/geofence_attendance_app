import 'dart:io'; // Required for File handling
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Package for camera/gallery
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase SDK

// Access the global Supabase client instance (initialized in main.dart)
final supabase = Supabase.instance.client;

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  bool _isLoading = false;
  File? _imageFile;
  final _imagePicker = ImagePicker();

  // Function to open the camera and capture a photo
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress image slightly
        maxWidth: 600, // Resize for faster uploads
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  // Function to upload the face and save the path
  Future<void> _uploadAndSaveFace() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a picture first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get the current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in. Cannot register face.');
      }

      // 2. Prepare file for upload
      final fileBytes = await _imageFile!.readAsBytes();
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = 'face_image.$fileExt';
      // We use the user's ID as the folder, as defined in our Storage policies
      final filePath = '${user.id}/$fileName';

      // 3. Upload to Supabase Storage
      await supabase.storage
          .from('user_face_images') // Your bucket name
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true, // Overwrite existing file if any
            ),
          );

      // 4. Get the public URL (or just use the path)
      final String imageUrl = supabase.storage
          .from('user_face_images')
          .getPublicUrl(filePath);

      // 5. Update the user's record in the 'profiles' table
      await supabase
          .from('profiles')
          .update({
            'face_image_path': imageUrl, // Save the public URL
          })
          .eq('id', user.id); // Where the profile ID matches the auth ID

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face registered successfully!')),
        );
        // Go back to the previous screen
        Navigator.of(context).pop();
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage Error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Your Face')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Image Preview Area ---
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
                child: _imageFile != null
                    ? ClipOval(
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.person_outline,
                        size: 100,
                        color: Colors.grey[600],
                      ),
              ),
              const SizedBox(height: 24),

              // --- Take Picture Button ---
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Picture'),
              ),
              const SizedBox(height: 16),

              // --- Save Button / Loading Indicator ---
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  // Button is disabled until an image is taken
                  onPressed: _imageFile != null ? _uploadAndSaveFace : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Capture & Save Face'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
