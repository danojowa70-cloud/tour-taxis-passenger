import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride.dart';
import 'auth_providers.dart';

// Real rides provider that fetches user's ride history from Supabase
final userRidesProvider = FutureProvider<List<Ride>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  
  if (user == null) return [];
  
  try {
    // Get rides for the current user
    final ridesData = await supabase
        .from('rides')
        .select('*, drivers(*)')
        .eq('passenger_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);
    
    return ridesData.map<Ride>((rideData) {
      final driver = rideData['drivers'] as Map<String, dynamic>?;
      
      return Ride(
        id: rideData['id'],
        pickupLocation: rideData['pickup_address'] ?? 'Unknown Location',
        dropoffLocation: rideData['destination_address'] ?? 'Unknown Destination',
        driverName: driver?['name'] ?? rideData['driver_name'] ?? 'Unknown Driver',
        driverCar: driver?['vehicle_info'] ?? '${driver?['vehicle_make']} ${driver?['vehicle_model']} - ${driver?['vehicle_plate']}' ?? 'Unknown Vehicle',
        fare: (rideData['fare'] as num?)?.toDouble() ?? 0.0,
        status: _mapStatus(rideData['status']),
        dateTime: DateTime.tryParse(rideData['created_at']) ?? DateTime.now(),
      );
    }).toList();
  } catch (e) {
    // Return empty list on error
    return [];
  }
});

// Recent rides provider (last 3 rides)
final recentRidesProvider = Provider<AsyncValue<List<Ride>>>((ref) {
  final userRides = ref.watch(userRidesProvider);
  
  return userRides.when(
    data: (rides) => AsyncData(rides.take(3).toList()),
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

// Live ride updates provider
final liveRideUpdatesProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, rideId) {
  final supabase = ref.watch(supabaseProvider);
  
  return supabase
      .from('rides')
      .stream(primaryKey: ['id'])
      .eq('id', rideId)
      .map((rides) => rides.isNotEmpty ? rides.first : null);
});

// Ride statistics provider
final rideStatsProvider = FutureProvider<RideStatistics>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  
  if (user == null) {
    return RideStatistics(
      totalRides: 0,
      totalSpent: 0.0,
      averageRating: 0.0,
      completedRides: 0,
      cancelledRides: 0,
    );
  }
  
  try {
    // Get basic statistics
    final stats = await supabase
        .rpc('get_passenger_stats', params: {'passenger_id': user.id});
    
    if (stats != null && stats is Map) {
      return RideStatistics(
        totalRides: stats['total_rides'] ?? 0,
        totalSpent: (stats['total_spent'] as num?)?.toDouble() ?? 0.0,
        averageRating: (stats['average_rating'] as num?)?.toDouble() ?? 0.0,
        completedRides: stats['completed_rides'] ?? 0,
        cancelledRides: stats['cancelled_rides'] ?? 0,
      );
    }
    
    // Fallback to manual calculation
    final rides = await supabase
        .from('rides')
        .select('status, fare')
        .eq('passenger_id', user.id);
    
    final completed = rides.where((r) => r['status'] == 'completed').toList();
    final cancelled = rides.where((r) => r['status'] == 'cancelled').toList();
    final totalSpent = completed.fold<double>(0.0, (sum, r) => sum + ((r['fare'] as num?)?.toDouble() ?? 0.0));
    
    return RideStatistics(
      totalRides: rides.length,
      totalSpent: totalSpent,
      averageRating: 0.0, // Would need ratings table
      completedRides: completed.length,
      cancelledRides: cancelled.length,
    );
  } catch (e) {
    // Return default statistics on error
    return RideStatistics(
      totalRides: 0,
      totalSpent: 0.0,
      averageRating: 0.0,
      completedRides: 0,
      cancelledRides: 0,
    );
  }
});

// Ride service provider
final rideServiceProvider = Provider<RideDataService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return RideDataService(supabase);
});

String _mapStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'accepted':
    case 'in_progress':
    case 'ongoing':
      return 'Ongoing';
    case 'requested':
      return 'Requested';
    default:
      return 'Unknown';
  }
}

class RideStatistics {
  final int totalRides;
  final double totalSpent;
  final double averageRating;
  final int completedRides;
  final int cancelledRides;
  
  RideStatistics({
    required this.totalRides,
    required this.totalSpent,
    required this.averageRating,
    required this.completedRides,
    required this.cancelledRides,
  });
}

class RideDataService {
  final SupabaseClient _client;
  
  RideDataService(this._client);
  
  Future<List<Ride>> getUserRides({int limit = 20}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    
    try {
      final ridesData = await _client
          .from('rides')
          .select('*, drivers(*)')
          .eq('passenger_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return ridesData.map<Ride>((rideData) {
        final driver = rideData['drivers'] as Map<String, dynamic>?;
        
        return Ride(
          id: rideData['id'],
          pickupLocation: rideData['pickup_address'] ?? 'Unknown Location',
          dropoffLocation: rideData['destination_address'] ?? 'Unknown Destination',
          driverName: driver?['name'] ?? rideData['driver_name'] ?? 'Unknown Driver',
          driverCar: driver?['vehicle_info'] ?? '${driver?['vehicle_make']} ${driver?['vehicle_model']} - ${driver?['vehicle_plate']}' ?? 'Unknown Vehicle',
          fare: (rideData['fare'] as num?)?.toDouble() ?? 0.0,
          status: _mapStatus(rideData['status']),
          dateTime: DateTime.tryParse(rideData['created_at']) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }
  
  Future<Ride?> getRideById(String rideId) async {
    try {
      final rideData = await _client
          .from('rides')
          .select('*, drivers(*)')
          .eq('id', rideId)
          .single();
      
      final driver = rideData['drivers'] as Map<String, dynamic>?;
      
      return Ride(
        id: rideData['id'],
        pickupLocation: rideData['pickup_address'] ?? 'Unknown Location',
        dropoffLocation: rideData['destination_address'] ?? 'Unknown Destination',
        driverName: driver?['name'] ?? rideData['driver_name'] ?? 'Unknown Driver',
        driverCar: driver?['vehicle_info'] ?? '${driver?['vehicle_make']} ${driver?['vehicle_model']} - ${driver?['vehicle_plate']}' ?? 'Unknown Vehicle',
        fare: (rideData['fare'] as num?)?.toDouble() ?? 0.0,
        status: _mapStatus(rideData['status']),
        dateTime: DateTime.tryParse(rideData['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      // Return null on error
      return null;
    }
  }
}