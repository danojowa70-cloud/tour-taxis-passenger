import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/scheduled_rides_history_service.dart';
import '../services/scheduled_ride_tracking_service.dart';

class ScheduledRidesHistoryScreen extends ConsumerStatefulWidget {
  final String passengerId;

  const ScheduledRidesHistoryScreen({
    super.key,
    required this.passengerId,
  });

  @override
  ConsumerState<ScheduledRidesHistoryScreen> createState() =>
      _ScheduledRidesHistoryScreenState();
}

class _ScheduledRidesHistoryScreenState extends ConsumerState<ScheduledRidesHistoryScreen> {
  final _service = ScheduledRidesHistoryService();
  final _trackingService = ScheduledRideTrackingService();
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _service.getScheduledRidesHistory(
      passengerId: widget.passengerId,
    );
    
    // Start tracking for ride updates (when driver enters OTP)
    _trackingService.listenForRideStarted(
      passengerId: widget.passengerId,
      onRideStarted: _handleRideStarted,
    );
  }
  
  @override
  void dispose() {
    _trackingService.stopListening();
    super.dispose();
  }
  
  void _handleRideStarted(String rideId, Map<String, dynamic> rideData) async {
    debugPrint('🎯 Ride started! Navigating to scheduled ride details for ride: $rideId');
    
    if (!mounted) return;
    
    // Navigate to scheduled ride details screen with ride ID
    await Navigator.of(context).pushNamed(
      '/scheduled-ride-details',
      arguments: {'rideId': rideId},
    );
    
    // Refresh history when returning
    if (mounted) {
      refreshHistory();
    }
  }
  
  void refreshHistory() {
    setState(() {
      _historyFuture = _service.getScheduledRidesHistory(
        passengerId: widget.passengerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final rides = snapshot.data ?? [];

          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No ride history',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _historyFuture = _service.getScheduledRidesHistory(
                  passengerId: widget.passengerId,
                );
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                return _RideHistoryCard(ride: ride);
              },
            ),
          );
        },
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  final Map<String, dynamic> ride;

  const _RideHistoryCard({required this.ride});
  
  void _navigateToRideDetails(BuildContext context) async {
    final status = ride['status'] as String;
    final rideId = ride['id'] as String?;
    
    // Prevent navigation for completed or cancelled rides
    if (status == 'completed' || status == 'cancelled') {
      debugPrint('🚫 Cannot open $status ride');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'completed' 
                ? 'This ride has been completed. Check your receipts for details.'
                : 'This ride was cancelled.',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: status == 'completed' ? Colors.green : Colors.orange,
        ),
      );
      return;
    }
    
    if (rideId != null) {
      // Navigate and wait for return
      await Navigator.of(context).pushNamed(
        '/scheduled-ride-details',
        arguments: {'rideId': rideId},
      );
      
      // Refresh the history when returning from details
      if (context.mounted) {
        // Trigger a rebuild by finding the parent state
        final parentState = context.findAncestorStateOfType<_ScheduledRidesHistoryScreenState>();
        parentState?.refreshHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // DEBUG: Log the ride payload
    debugPrint('\n📋 === RENDERING RIDE CARD ===');
    debugPrint('🚗 Ride ID: ${ride['id']}');
    debugPrint('📊 Status: ${ride['status']}');
    debugPrint('🔑 All fields in ride object:');
    ride.forEach((key, value) {
      if (key == 'otp') {
        debugPrint('  🔓 $key: "$value" ✅ OTP FOUND');
      } else {
        debugPrint('  • $key: ${value.toString().length > 50 ? '${value.toString().substring(0, 50)}...' : value}');
      }
    });
    debugPrint('📋 === END CARD RENDER ===\n');
    
    final status = ride['status'] as String;
    final otp = ride['otp'] as String?;
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    final isClickable = !isCompleted && !isCancelled;
    
    // Debug OTP extraction
    debugPrint('🔎 OTP extraction: otp variable = "$otp" (null: ${otp == null})');
    
    final scheduledTime = DateTime.parse(ride['scheduled_time'] as String);
    final createdAt = DateTime.parse(ride['created_at'] as String);
    final driverInfo = ride['drivers'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: isClickable ? () => _navigateToRideDetails(context) : null,
      child: Opacity(
        opacity: (isCompleted || isCancelled) ? 0.7 : 1.0,
        child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride['pickup_location'] ?? 'Pickup Location',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: (isCompleted || isCancelled) 
                                  ? TextDecoration.lineThrough 
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ride['destination_location'] ?? 'Destination',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              decoration: (isCompleted || isCancelled) 
                                  ? TextDecoration.lineThrough 
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            const Divider(height: 24),

            // Scheduled time and ride ID
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(scheduledTime),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // OTP section - show for confirmed, in_progress, or completed rides
            if (status == 'confirmed' || status == 'in_progress' || status == 'completed' || status == 'pending')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          status == 'confirmed'
                              ? 'OTP to Share with Driver'
                              : 'OTP Given to Driver',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (status == 'confirmed')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Waiting for Driver',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (otp != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            otp,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              letterSpacing: 2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            iconSize: 20,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('OTP copied: $otp'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      Text(
                        'Generating OTP...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Driver info if available
            if (driverInfo != null && (status == 'completed' || status == 'in_progress'))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver Details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            driverInfo['name'] ?? 'Unknown Driver',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (driverInfo['phone'] != null) ...[const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              driverInfo['phone'] as String,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (driverInfo['vehicle_number'] != null) ...[const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              driverInfo['vehicle_number'] as String,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Additional info
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Booked on ${DateFormat('MMM dd, yyyy').format(createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            
            // Completed/Cancelled message
            if (isCompleted || isCancelled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted 
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.cancel,
                      color: isCompleted ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCompleted
                            ? 'This ride has been completed. Check your receipts for details.'
                            : 'This ride was cancelled.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCompleted ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
            // Overlay for non-clickable rides
            if (!isClickable)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
    )));
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
