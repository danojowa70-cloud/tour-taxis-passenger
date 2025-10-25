import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_providers.dart';
import '../providers/auth_providers.dart';
import '../services/profile_image_service.dart';
import '../services/error_handler_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(ridesProvider);
    final isDark = ref.watch(themeDarkProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final subtle = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                children: [
                  GestureDetector(
                    onTap: () => _showImagePicker(context, ref),
                    child: Stack(
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final userProfile = ref.watch(userProfileProvider);
                            return userProfile.when(
                              data: (profile) {
                                final avatarUrl = profile?['avatar_url'];
                                if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 28,
                                    backgroundImage: NetworkImage(avatarUrl.toString()),
                                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                  );
                                }
                                return CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person_outline, size: 28),
                                );
                              },
                              loading: () => CircleAvatar(
                                radius: 28,
                                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (_, __) => CircleAvatar(
                                radius: 28,
                                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                child: const Icon(Icons.person_outline, size: 28),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final userProfile = ref.watch(userProfileProvider);
                            return userProfile.when(
                              data: (profile) {
                                final name = profile?['name'] ?? 
                                            user?.userMetadata?['full_name'] ?? 
                                            user?.email?.split('@')[0] ?? 
                                            'Guest';
                                return Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                );
                              },
                              loading: () => Text(
                                user?.email?.split('@')[0] ?? 'Loading...',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              error: (_, __) => Text(
                                user?.email ?? 'Guest',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            );
                          },
                        ),
                        Text('Rides taken: ${rides.length}', style: TextStyle(color: subtle)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  title: const Text('Dark mode'),
                  value: isDark,
                  onChanged: (val) => ref.read(themeDarkProvider.notifier).setDark(val),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                    }
                  },
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Update Profile Picture',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  context: context,
                  ref: ref,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  source: ImageSource.camera,
                ),
                _buildImageSourceOption(
                  context: context,
                  ref: ref,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                ),
                _buildImageSourceOption(
                  context: context,
                  ref: ref,
                  icon: Icons.delete,
                  label: 'Remove',
                  source: null,
                  isDelete: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    ImageSource? source,
    bool isDelete = false,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.of(context).pop(); // Close bottom sheet
        await _handleImageAction(context, ref, source, isDelete);
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isDelete 
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isDelete 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDelete 
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageAction(
    BuildContext context,
    WidgetRef ref,
    ImageSource? source,
    bool isDelete,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profileImageService = ProfileImageService(Supabase.instance.client);

      if (isDelete) {
        // Delete current profile image
        final userProfile = ref.read(userProfileProvider);
        final currentImageUrl = userProfile.value?['avatar_url'];
        
        await ErrorHandlerService.handleAsync<void>(
          () => profileImageService.deleteProfileImage(user.id, currentImageUrl),
          context: context,
          errorMessage: 'Failed to remove profile picture',
        );
        
        // Refresh user profile
        ref.invalidate(userProfileProvider);
        
        if (context.mounted) {
          ErrorHandlerService.showSuccess(
            context,
            'Profile picture removed successfully',
          );
        }
      } else if (source != null) {
        // Upload new profile image
        final imageUrl = await ErrorHandlerService.handleAsync<String?>(
          () => profileImageService.pickAndUploadProfileImage(
            source: source,
            userId: user.id,
          ),
          context: context,
          errorMessage: 'Failed to update profile picture',
        );

        if (imageUrl != null) {
          // Refresh user profile
          ref.invalidate(userProfileProvider);
          
          if (context.mounted) {
            ErrorHandlerService.showSuccess(
              context,
              'Profile picture updated successfully',
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandlerService().handleError(
          e,
          context: context,
          userMessage: 'Failed to update profile picture',
        );
      }
    }
  }
}


