import 'package:flutter/material.dart';
import '../services/permission_service.dart';

/// A widget that can be shown when a specific permission is needed
class PermissionRequestWidget extends StatelessWidget {
  final AppPermissionType permission;
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;
  final Widget? child;

  const PermissionRequestWidget({
    super.key,
    required this.permission,
    required this.title,
    required this.message,
    required this.icon,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionService().isPermissionGranted(permission),
      builder: (context, snapshot) {
        final isGranted = snapshot.data ?? false;
        
        if (isGranted && child != null) {
          return child!;
        }
        
        if (isGranted) {
          return const SizedBox.shrink();
        }
        
        return _buildPermissionRequest(context);
      },
    );
  }

  Widget _buildPermissionRequest(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Message
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onPermissionDenied?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Not Now'),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    final granted = await PermissionService().requestPermissionsWithDialog(
                      context,
                      [permission],
                    );
                    
                    if (granted) {
                      onPermissionGranted?.call();
                    } else {
                      onPermissionDenied?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Grant Permission'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Factory constructors for common permission requests
  
  static PermissionRequestWidget location({
    Key? key,
    VoidCallback? onPermissionGranted,
    VoidCallback? onPermissionDenied,
    Widget? child,
  }) {
    return PermissionRequestWidget(
      key: key,
      permission: AppPermissionType.location,
      title: 'Location Access Needed',
      message: 'We need access to your location to show nearby drivers and track your ride.',
      icon: Icons.location_on,
      onPermissionGranted: onPermissionGranted,
      onPermissionDenied: onPermissionDenied,
      child: child,
    );
  }
  
  static PermissionRequestWidget camera({
    Key? key,
    VoidCallback? onPermissionGranted,
    VoidCallback? onPermissionDenied,
    Widget? child,
  }) {
    return PermissionRequestWidget(
      key: key,
      permission: AppPermissionType.camera,
      title: 'Camera Access Needed',
      message: 'We need access to your camera to take profile photos and scan payment cards.',
      icon: Icons.camera_alt,
      onPermissionGranted: onPermissionGranted,
      onPermissionDenied: onPermissionDenied,
      child: child,
    );
  }
  
  static PermissionRequestWidget notification({
    Key? key,
    VoidCallback? onPermissionGranted,
    VoidCallback? onPermissionDenied,
    Widget? child,
  }) {
    return PermissionRequestWidget(
      key: key,
      permission: AppPermissionType.notification,
      title: 'Notification Access Needed',
      message: 'We need to send you notifications about ride updates and driver messages.',
      icon: Icons.notifications,
      onPermissionGranted: onPermissionGranted,
      onPermissionDenied: onPermissionDenied,
      child: child,
    );
  }
}

/// A simple banner that shows when a permission is needed
class PermissionBanner extends StatelessWidget {
  final AppPermissionType permission;
  final String message;
  final VoidCallback? onTap;

  const PermissionBanner({
    super.key,
    required this.permission,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionService().isPermissionGranted(permission),
      builder: (context, snapshot) {
        final isGranted = snapshot.data ?? false;
        
        if (isGranted) {
          return const SizedBox.shrink();
        }
        
        final theme = Theme.of(context);
        
        return Container(
          margin: const EdgeInsets.all(16),
          child: Material(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap ?? () async {
                await PermissionService().requestPermissionsWithDialog(
                  context,
                  [permission],
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _getPermissionIcon(),
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getPermissionIcon() {
    switch (permission) {
      case AppPermissionType.location:
        return Icons.location_on;
      case AppPermissionType.notification:
        return Icons.notifications;
      case AppPermissionType.camera:
        return Icons.camera_alt;
      case AppPermissionType.photos:
        return Icons.photo_library;
      case AppPermissionType.storage:
        return Icons.storage;
      case AppPermissionType.phone:
        return Icons.phone;
      case AppPermissionType.microphone:
        return Icons.mic;
      case AppPermissionType.contacts:
        return Icons.contacts;
    }
  }
}