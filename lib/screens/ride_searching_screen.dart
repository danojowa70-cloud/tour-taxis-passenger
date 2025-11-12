import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/realtime_providers.dart';
import '../providers/socket_ride_providers.dart';
import '../providers/ride_flow_providers.dart';

class RideSearchingScreen extends ConsumerStatefulWidget {
  const RideSearchingScreen({super.key});

  @override
  ConsumerState<RideSearchingScreen> createState() => _RideSearchingScreenState();
}

class _RideSearchingScreenState extends ConsumerState<RideSearchingScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotationAnimation;
  bool _hasNavigated = false; // Prevent multiple navigation
  StreamSubscription? _rideAcceptedSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _rotationController, curve: Curves.linear));
    
    // Reset navigation flag for new search session
    _hasNavigated = false;
    
    // Clear any previous error states
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('🔄 Clearing previous socket errors for new ride search');
        ref.read(socketRideProvider.notifier).clearError();
        
        // Set up direct socket listener for ride acceptance
        _setupRideAcceptedListener();
      }
    });
  }
  
  void _setupRideAcceptedListener() {
    final socketService = ref.read(socketServiceProvider);
    _rideAcceptedSubscription = socketService.rideAcceptedStream.listen((data) {
      debugPrint('🎉 DIRECT LISTENER: Ride accepted event in searching screen!');
      debugPrint('📝 Event data: $data');
      
      // Force state refresh to trigger navigation
      if (mounted) {
        setState(() {
          // This will trigger the build method and postFrameCallback
        });
      }
    });
  }

  @override
  void dispose() {
    _rideAcceptedSubscription?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideRealtimeProvider);
    final socketState = ref.watch(socketRideProvider);
    final theme = Theme.of(context);

    // Handle navigation based on either Supabase or Socket state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final supaStatus = rideState.status;
      final socketStatus = socketState.status;
      
      // Prioritize socket status for real-time events
      final status = socketStatus != 'idle' && socketStatus != 'requesting' ? socketStatus : supaStatus;
      
      debugPrint('🔍 RideSearchingScreen - Supabase status: $supaStatus, Socket status: $socketStatus, Final status: $status');
      debugPrint('🔍 Navigation lock: $_hasNavigated');
      
      if (socketState.currentRide != null) {
        debugPrint('🚗 Current ride in socket state: ${socketState.currentRide!.id}, status: ${socketState.currentRide!.status}');
      }
      
      // Check ride object status as well
      final rideObjectStatus = socketState.currentRide?.status;
      if (rideObjectStatus != null) {
        debugPrint('🚗 Ride object status: $rideObjectStatus');
      }
      
      // Use ride object status if socket state status doesn't match
      final effectiveStatus = (rideObjectStatus == 'accepted' || rideObjectStatus == 'started') 
          ? rideObjectStatus 
          : status;
      
      debugPrint('🎯 Effective status for navigation: $effectiveStatus');
      
      // Priority statuses that override the navigation lock
      final isPriorityStatus = effectiveStatus == 'accepted' || effectiveStatus == 'started' || effectiveStatus == 'completed';
      
      // Skip if already navigated and this is not a priority status
      if (_hasNavigated && !isPriorityStatus) {
        debugPrint('⚠️ Already navigated and not a priority status, skipping');
        return;
      }
      
      switch (effectiveStatus) {
        case 'accepted':
        case 'started': // Also handle ride_started event
          // Reset navigation flag and close any dialogs if showing no_drivers/timeout
          if (_hasNavigated) {
            debugPrint('🔄 Resetting navigation flag - ride was accepted after timeout/no_drivers');
            Navigator.of(context, rootNavigator: true).popUntil((route) => route.settings.name == '/searching' || route.isFirst);
          }
          _hasNavigated = true; // Mark as navigated to prevent multiple calls
          debugPrint('✅ Ride accepted/started! Navigating to ride details...');
          // Bridge data from socket to ride flow for details screen
          final r = socketState.currentRide;
          if (r != null) {
            debugPrint('📦 Updating ride flow provider with ride data: ${r.id}');
            ref.read(rideFlowProvider.notifier).setRideId(r.id);
            ref.read(rideFlowProvider.notifier).updateFrom(
              pickup: r.pickupAddress,
              destination: r.destinationAddress,
              pickupLatLng: {'lat': r.pickupLatitude, 'lng': r.pickupLongitude},
              destinationLatLng: {'lat': r.destinationLatitude, 'lng': r.destinationLongitude},
            );
            debugPrint('✅ Ride flow provider updated');
          } else {
            debugPrint('⚠️ No current ride data available in socket state!');
          }
          debugPrint('📍 Navigating to /ride-details');
          Navigator.of(context).pushReplacementNamed('/ride-details');
          break;
        case 'completed':
          if (!_hasNavigated) {
            _hasNavigated = true;
            Navigator.of(context).pushReplacementNamed('/payments');
          }
          break;
        case 'cancelled':
          if (!_hasNavigated) {
            _hasNavigated = true;
            debugPrint('❌ Ride was cancelled, clearing state and going back');
            // Clear ride state before going back
            ref.read(rideFlowProvider.notifier).clearAll();
            Navigator.of(context).pop();
          }
          break;
        case 'timeout':
        case 'no_drivers':
          if (!_hasNavigated) {
            _hasNavigated = true;
            _showNoDriversDialog();
          }
          break;
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        debugPrint('⚠️ User pressed back button - cancelling ride request');
        await ref.read(rideRealtimeProvider.notifier).cancelRide(
          reason: 'Passenger pressed back button',
        );
        // Clear ride state
        ref.read(rideFlowProvider.notifier).clearAll();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Custom App Bar
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                  onPressed: () async {
                        debugPrint('🚫 Cancelling ride request from search screen');
                        await ref.read(rideRealtimeProvider.notifier).cancelRide(
                          reason: 'Passenger cancelled during search',
                        );
                        // Clear ride state
                        ref.read(rideFlowProvider.notifier).clearAll();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Finding your driver',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Animated search indicator
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer rotating ring
                        Transform.rotate(
                          angle: _rotationAnimation.value * 2 * 3.14159,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _SearchingPainter(theme.colorScheme.primary),
                            ),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Status message
              Text(
                _getStatusMessage(rideState.status),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                _getStatusDescription(rideState.status),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Driver count indicator
              if (rideState.events.isNotEmpty)
                _buildDriverCountIndicator(rideState, theme),
              
              const Spacer(),
              
              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () async {
                    debugPrint('🚫 Cancelling ride request from cancel button');
                    await ref.read(rideRealtimeProvider.notifier).cancelRide(
                      reason: 'Passenger cancelled',
                    );
                    // Clear ride state
                    ref.read(rideFlowProvider.notifier).clearAll();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Cancel Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'requested':
        return 'Searching for drivers';
      case 'drivers_found':
        return 'Drivers found!';
      case 'accepted':
        return 'Driver accepted!';
      case 'no_drivers':
        return 'No drivers available';
      default:
        return 'Finding your driver';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'requested':
        return 'We\'re looking for the best driver in your area';
      case 'drivers_found':
        return 'We found drivers nearby and are notifying them';
      case 'accepted':
        return 'A driver has accepted your request';
      case 'no_drivers':
        return 'Please try again later or adjust your pickup location';
      default:
        return 'Hold on while we connect you with a driver';
    }
  }

  Widget _buildDriverCountIndicator(RideRealtimeState rideState, ThemeData theme) {
    final driversFoundEvent = rideState.events
        .where((e) => e['event_type'] == 'ride:drivers_found')
        .lastOrNull;
    
    if (driversFoundEvent != null) {
      final payload = driversFoundEvent['payload'] as Map<String, dynamic>?;
      final driverCount = payload?['driver_count'] ?? 0;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_taxi,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '$driverCount drivers notified',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  void _showNoDriversDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No drivers available'),
        content: const Text(
          'We couldn\'t find any drivers in your area right now. Please try again later or consider adjusting your pickup location.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the searching animation
class _SearchingPainter extends CustomPainter {
  final Color color;
  
  _SearchingPainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Draw partial arcs to create a "radar" effect
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      3.14159, // Half circle
      false,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


