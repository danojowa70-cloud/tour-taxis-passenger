import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileImageService {
  final SupabaseClient _client;
  final ImagePicker _picker = ImagePicker();

  ProfileImageService(this._client);

  /// Pick image from gallery or camera and upload to profile
  Future<String?> pickAndUploadProfileImage({
    required ImageSource source,
    required String userId,
  }) async {
    try {
      // Request permission
      if (source == ImageSource.camera) {
        final cameraPermission = await Permission.camera.request();
        if (cameraPermission != PermissionStatus.granted) {
          throw Exception('Camera permission is required');
        }
      } else {
        if (!kIsWeb && Platform.isAndroid) {
          final storagePermission = await Permission.photos.request();
          if (storagePermission != PermissionStatus.granted) {
            throw Exception('Storage permission is required');
          }
        }
      }

      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return null; // User cancelled
      }

      // Upload to Supabase Storage
      final imageUrl = await _uploadImageToStorage(pickedFile, userId);

      // Update user profile with new avatar URL
      await _updateUserProfile(userId, imageUrl);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Upload image file to Supabase Storage
  Future<String> _uploadImageToStorage(XFile imageFile, String userId) async {
    try {
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase Storage
      await _client.storage.from('avatars').uploadBinary(
        fileName,
        await imageFile.readAsBytes(),
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      // Get public URL
      final imageUrl = _client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image to storage: $e');
    }
  }

  /// Update user profile in both auth metadata and passengers table
  Future<void> _updateUserProfile(String userId, String imageUrl) async {
    try {
      // Update auth user metadata
      await _client.auth.updateUser(
        UserAttributes(
          data: {'avatar_url': imageUrl},
        ),
      );

      // Update passengers table
      await _client.from('passengers').upsert({
        'auth_user_id': userId,
        'avatar_url': imageUrl,
      }, onConflict: 'auth_user_id');
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Delete current profile image
  Future<void> deleteProfileImage(String userId, String? currentImageUrl) async {
    try {
      if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
        // Extract file name from URL
        final uri = Uri.parse(currentImageUrl);
        final fileName = uri.pathSegments.last;

        // Delete from storage
        await _client.storage.from('avatars').remove([fileName]);
      }

      // Clear avatar URL from profile
      await _updateUserProfile(userId, '');
    } catch (e) {
      throw Exception('Failed to delete profile image: $e');
    }
  }

  /// Show image source selection dialog options
  static List<ImageSourceOption> getImageSourceOptions() {
    return [
      const ImageSourceOption(
        title: 'Camera',
        subtitle: 'Take a new photo',
        icon: 'camera',
        source: ImageSource.camera,
      ),
      const ImageSourceOption(
        title: 'Gallery',
        subtitle: 'Choose from gallery',
        icon: 'gallery',
        source: ImageSource.gallery,
      ),
    ];
  }
}

class ImageSourceOption {
  final String title;
  final String subtitle;
  final String icon;
  final ImageSource source;

  const ImageSourceOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.source,
  });
}