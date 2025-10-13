import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permission_service.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _isLoading = false;
  PermissionCheckResult? _permissionResult;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await PermissionService().checkAllEssentialPermissions();
      setState(() => _permissionResult = result);
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      final essentialPermissions = [
        AppPermissionType.location,
        AppPermissionType.notification,
        AppPermissionType.camera,
        AppPermissionType.storage,
      ];
      
      final granted = await PermissionService().requestPermissionsWithDialog(
        context,
        essentialPermissions,
        customTitle: 'Welcome to TourTaxi',
        customMessage: 'To get started, we need a few permissions to provide you with the best ride experience.',
      );
      
      if (granted) {
        // All permissions granted, navigate to main app
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Some permissions denied, refresh the status
        await _checkPermissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permissions: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              _buildHeader(theme),
              
              const SizedBox(height: 40),
              
              // Permissions List
              Expanded(
                child: _buildPermissionsList(theme),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        // App Icon/Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withAlpha(200),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_taxi,
            size: 50,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          'Welcome to TourTaxi',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Text(
          'To provide you with the best ride experience, we need access to a few device features.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(180),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionsList(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final permissions = [
      _PermissionInfo(
        type: AppPermissionType.location,
        title: 'Location Services',
        description: 'Find nearby drivers and track your ride',
        icon: Icons.location_on,
        isEssential: true,
      ),
      _PermissionInfo(
        type: AppPermissionType.notification,
        title: 'Push Notifications',
        description: 'Get updates about your rides and driver messages',
        icon: Icons.notifications,
        isEssential: true,
      ),
      _PermissionInfo(
        type: AppPermissionType.camera,
        title: 'Camera Access',
        description: 'Take profile photos and scan payment cards',
        icon: Icons.camera_alt,
        isEssential: false,
      ),
      _PermissionInfo(
        type: AppPermissionType.storage,
        title: 'Storage Access',
        description: 'Save ride receipts and access photos',
        icon: Icons.storage,
        isEssential: false,
      ),
    ];

    return ListView.separated(
      itemCount: permissions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final permission = permissions[index];
        final isGranted = _permissionResult?.isGranted(permission.type) ?? false;
        
        return _buildPermissionTile(theme, permission, isGranted);
      },
    );
  }

  Widget _buildPermissionTile(
    ThemeData theme,
    _PermissionInfo permission,
    bool isGranted,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted 
              ? theme.colorScheme.primary.withAlpha(100)
              : theme.colorScheme.outline.withAlpha(50),
          width: isGranted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Permission Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted 
                  ? theme.colorScheme.primary.withAlpha(50)
                  : theme.colorScheme.outline.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              permission.icon,
              color: isGranted 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(150),
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Permission Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      permission.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (permission.isEssential) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Required',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  permission.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Status Indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isGranted 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check : Icons.close,
              color: isGranted 
                  ? Colors.white
                  : theme.colorScheme.onSurface.withAlpha(150),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final allGranted = _permissionResult?.allGranted ?? false;
    
    return Column(
      children: [
        if (!allGranted) ...[
          // Grant Permissions Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _requestAllPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Grant Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
        ],
        
        // Continue Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(
                color: theme.colorScheme.outline.withAlpha(100),
              ),
            ),
            child: Text(
              allGranted ? 'Continue to App' : 'Skip for Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        
        if (!allGranted) ...[
          const SizedBox(height: 16),
          
          Text(
            'You can enable permissions later in Settings',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _PermissionInfo {
  final AppPermissionType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isEssential;

  _PermissionInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.isEssential,
  });
}