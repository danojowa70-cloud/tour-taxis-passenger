import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef OnScheduledRideStarted = void Function(String rideId, Map<String, dynamic> rideData);

class ScheduledRideTrackingService {
  static final ScheduledRideTrackingService _instance = ScheduledRideTrackingService._internal();
  
  factory ScheduledRideTrackingService() {
    return _instance;
  }
  
  ScheduledRideTrackingService._internal();
  
  RealtimeChannel? _realtimeChannel;
  OnScheduledRideStarted? _onRideStartedCallback;
  
  /// Initialize listening for scheduled ride updates
  void listenForRideStarted({
    required String passengerId,
    required OnScheduledRideStarted onRideStarted,
  }) {
    _onRideStartedCallback = onRideStarted;
    
    _realtimeChannel?.unsubscribe();
    
    _realtimeChannel = Supabase.instance.client
        .channel('scheduled_rides_updates_$passengerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'scheduled_rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'passenger_id',
            value: passengerId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            
            final oldStatus = oldRecord['status'] as String? ?? '';
            final newStatus = newRecord['status'] as String? ?? '';
            final rideId = newRecord['id'] as String;
            
            debugPrint(
              '📍 Scheduled ride status change: $oldStatus → $newStatus for ride $rideId',
            );
            
            // When driver verifies OTP, status changes from 'confirmed' or 'in_progress'
            // Call the callback to navigate to ride details screen
            if (newStatus == 'in_progress' || newStatus == 'started') {
              debugPrint(
                '🎉 Ride started! Driver verified OTP. Ride ID: $rideId',
              );
              
              if (_onRideStartedCallback != null) {
                _onRideStartedCallback!(rideId, newRecord);
              }
            }
          },
        )
        .subscribe();
    
    debugPrint(
      '🔔 Listening for scheduled ride updates for passenger: $passengerId',
    );
  }
  
  /// Stop listening to scheduled ride updates
  void stopListening() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _onRideStartedCallback = null;
    debugPrint(
      '🔕 Stopped listening for scheduled ride updates',
    );
  }
}
