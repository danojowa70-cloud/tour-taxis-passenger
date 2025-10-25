import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:permission_handler/permission_handler.dart' show PermissionStatus;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check and request all essential permissions for the app
  Future<PermissionCheckResult> checkAllEssentialPermissions() async {
    final results = <AppPermissionType, PermissionStatus>{};
    
    // Check location permission (most critical)
    final locationStatus = await _checkLocationPermission();
    results[AppPermissionType.location] = locationStatus;
    
    // Check notification permission
    final notificationStatus = await _checkNotificationPermission();
    results[AppPermissionType.notification] = notificationStatus;
    
    // Check camera permission (for profile photos and card scanning)
    final cameraStatus = await perm.Permission.camera.status;
    results[AppPermissionType.camera] = cameraStatus;
    
    // Check photo library permission
    if (Platform.isIOS) {
      final photosStatus = await perm.Permission.photos.status;
      results[AppPermissionType.photos] = photosStatus;
    } else if (Platform.isAndroid) {
      final storageStatus = await perm.Permission.storage.status;
      results[AppPermissionType.storage] = storageStatus;
    }
    
    // Check phone permission (for emergency calls)
    final phoneStatus = await perm.Permission.phone.status;
    results[AppPermissionType.phone] = phoneStatus;
    
    return PermissionCheckResult(
      permissions: results,
      allGranted: results.values.every(
        (status) => status == PermissionStatus.granted
      ),
    );
  }

  /// Show permission explanation dialog and request permissions
  Future<bool> requestPermissionsWithDialog(
    BuildContext context,
    List<AppPermissionType> permissions, {
    String? customTitle,
    String? customMessage,
  }) async {
    // Show explanation dialog first
    final shouldProceed = await _showPermissionExplanationDialog(
      context,
      permissions,
      customTitle: customTitle,
      customMessage: customMessage,
    );
    
    if (!shouldProceed) return false;
    
    // Request permissions
    final results = await requestMultiplePermissions(permissions);
    
    // Check if any permissions were denied
    final deniedPermissions = results.entries
        .where((entry) => entry.value != PermissionStatus.granted)
        .map((entry) => entry.key)
        .toList();
    
    if (deniedPermissions.isNotEmpty && context.mounted) {
      await _showPermissionDeniedDialog(context, deniedPermissions);
      return false;
    }
    
    return deniedPermissions.isEmpty;
  }

  /// Request multiple permissions
  Future<Map<AppPermissionType, PermissionStatus>> requestMultiplePermissions(
    List<AppPermissionType> permissions,
  ) async {
    final results = <AppPermissionType, PermissionStatus>{};
    
    for (final permissionType in permissions) {
      final status = await requestSinglePermission(permissionType);
      results[permissionType] = status;
    }
    
    return results;
  }

  /// Request a single permission
  Future<PermissionStatus> requestSinglePermission(
    AppPermissionType permissionType,
  ) async {
    switch (permissionType) {
      case AppPermissionType.location:
        return await _requestLocationPermission();
        
      case AppPermissionType.notification:
        return await _requestNotificationPermission();
        
      case AppPermissionType.camera:
        return await perm.Permission.camera.request();
        
      case AppPermissionType.photos:
        if (Platform.isIOS) {
          return await perm.Permission.photos.request();
        }
        return PermissionStatus.granted;
        
      case AppPermissionType.storage:
        if (Platform.isAndroid) {
          return await perm.Permission.storage.request();
        }
        return PermissionStatus.granted;
        
      case AppPermissionType.phone:
        return await perm.Permission.phone.request();
        
      case AppPermissionType.microphone:
        return await perm.Permission.microphone.request();
        
      case AppPermissionType.contacts:
        return await perm.Permission.contacts.request();
    }
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted(AppPermissionType permissionType) async {
    final status = await getPermissionStatus(permissionType);
    return status == PermissionStatus.granted;
  }

  /// Get current permission status
  Future<PermissionStatus> getPermissionStatus(
    AppPermissionType permissionType,
  ) async {
    switch (permissionType) {
      case AppPermissionType.location:
        return await _checkLocationPermission();
        
      case AppPermissionType.notification:
        return await _checkNotificationPermission();
        
      case AppPermissionType.camera:
        return await perm.Permission.camera.status;
        
      case AppPermissionType.photos:
        if (Platform.isIOS) {
          return await perm.Permission.photos.status;
        }
        return PermissionStatus.granted;
        
      case AppPermissionType.storage:
        if (Platform.isAndroid) {
          return await perm.Permission.storage.status;
        }
        return PermissionStatus.granted;
        
      case AppPermissionType.phone:
        return await perm.Permission.phone.status;
        
      case AppPermissionType.microphone:
        return await perm.Permission.microphone.status;
        
      case AppPermissionType.contacts:
        return await perm.Permission.contacts.status;
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await perm.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Location permission handling (special case)
  Future<PermissionStatus> _checkLocationPermission() async {
    if (kIsWeb) return PermissionStatus.granted;
    
    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return PermissionStatus.denied;
      case LocationPermission.deniedForever:
        return PermissionStatus.permanentlyDenied;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return PermissionStatus.granted;
      case LocationPermission.unableToDetermine:
        return PermissionStatus.denied;
    }
  }

  Future<PermissionStatus> _requestLocationPermission() async {
    if (kIsWeb) return PermissionStatus.granted;
    
    final permission = await Geolocator.requestPermission();
    switch (permission) {
      case LocationPermission.denied:
        return PermissionStatus.denied;
      case LocationPermission.deniedForever:
        return PermissionStatus.permanentlyDenied;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return PermissionStatus.granted;
      case LocationPermission.unableToDetermine:
        return PermissionStatus.denied;
    }
  }

  /// Notification permission handling
  Future<PermissionStatus> _checkNotificationPermission() async {
    if (kIsWeb) return PermissionStatus.granted;
    
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return PermissionStatus.granted;
        case AuthorizationStatus.denied:
          return PermissionStatus.denied;
        case AuthorizationStatus.notDetermined:
          return PermissionStatus.denied;
      }
    }
    
    return await perm.Permission.notification.status;
  }

  Future<PermissionStatus> _requestNotificationPermission() async {
    if (kIsWeb) return PermissionStatus.granted;
    
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return PermissionStatus.granted;
        default:
          return PermissionStatus.denied;
      }
    }
    
    return await perm.Permission.notification.request();
  }

  /// Show permission explanation dialog
  Future<bool> _showPermissionExplanationDialog(
    BuildContext context,
    List<AppPermissionType> permissions, {
    String? customTitle,
    String? customMessage,
  }) async {
    final title = customTitle ?? 'Permissions Required';
    final message = customMessage ?? _generatePermissionMessage(permissions);
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.security,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            ...permissions.map((permission) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _getPermissionIcon(permission),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPermissionDescription(permission),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show permission denied dialog
  Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    List<AppPermissionType> deniedPermissions,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Permissions Needed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Some permissions were denied. The app may not work properly without these permissions.',
            ),
            const SizedBox(height: 16),
            ...deniedPermissions.map((permission) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    _getPermissionIcon(permission),
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPermissionName(permission),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              perm.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _generatePermissionMessage(List<AppPermissionType> permissions) {
    return 'TourTaxi needs the following permissions to provide the best experience:';
  }

  String _getPermissionName(AppPermissionType permission) {
    switch (permission) {
      case AppPermissionType.location:
        return 'Location';
      case AppPermissionType.notification:
        return 'Notifications';
      case AppPermissionType.camera:
        return 'Camera';
      case AppPermissionType.photos:
        return 'Photos';
      case AppPermissionType.storage:
        return 'Storage';
      case AppPermissionType.phone:
        return 'Phone';
      case AppPermissionType.microphone:
        return 'Microphone';
      case AppPermissionType.contacts:
        return 'Contacts';
    }
  }

  String _getPermissionDescription(AppPermissionType permission) {
    switch (permission) {
      case AppPermissionType.location:
        return 'To show your location and find nearby drivers';
      case AppPermissionType.notification:
        return 'To notify you about ride updates and driver messages';
      case AppPermissionType.camera:
        return 'To take profile photos and scan payment cards';
      case AppPermissionType.photos:
        return 'To select profile photos from your gallery';
      case AppPermissionType.storage:
        return 'To save receipts and access photos';
      case AppPermissionType.phone:
        return 'To make emergency calls if needed';
      case AppPermissionType.microphone:
        return 'For voice messages with your driver';
      case AppPermissionType.contacts:
        return 'To share ride details with emergency contacts';
    }
  }

  IconData _getPermissionIcon(AppPermissionType permission) {
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

enum AppPermissionType {
  location,
  notification,
  camera,
  photos,
  storage,
  phone,
  microphone,
  contacts,
}

class PermissionCheckResult {
  final Map<AppPermissionType, PermissionStatus> permissions;
  final bool allGranted;

  PermissionCheckResult({
    required this.permissions,
    required this.allGranted,
  });

  bool isGranted(AppPermissionType permission) {
    return permissions[permission] == PermissionStatus.granted;
  }
  bool isDenied(AppPermissionType permission) {
    return permissions[permission] == PermissionStatus.denied;
  }

  bool isPermanentlyDenied(AppPermissionType permission) {
    return permissions[permission] == PermissionStatus.permanentlyDenied;
  }

  List<AppPermissionType> get deniedPermissions {
    return permissions.entries
        .where((entry) => entry.value != PermissionStatus.granted)
        .map((entry) => entry.key)
        .toList();
  }

  List<AppPermissionType> get grantedPermissions {
    return permissions.entries
        .where((entry) => entry.value == PermissionStatus.granted)
        .map((entry) => entry.key)
        .toList();
  }
}
