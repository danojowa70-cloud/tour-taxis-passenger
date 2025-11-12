import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:convert';
import '../models/boarding_pass.dart';

// Service for generating QR codes and boarding passes
class BoardingPassService {
  static String generateBookingId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000);
    return 'BP${timestamp.toString().substring(8)}$random';
  }

  static String generateQRCode(String rideEventId) {
    // In a real app, this would generate a proper QR code data string
    // that can be decoded by boarding pass scanners
    return 'BOARDING_PASS:$rideEventId:${DateTime.now().millisecondsSinceEpoch}';
  }

  static String getOperatorName(PremiumVehicleType vehicleType) {
    switch (vehicleType) {
      case PremiumVehicleType.chopper:
        return 'SkyTour Helicopters';
      case PremiumVehicleType.privateJet:
        return 'Elite Aviation';
      case PremiumVehicleType.cruise:
        return 'Ocean Luxury Cruises';
    }
  }

  static String getOperatorLogo(PremiumVehicleType vehicleType) {
    switch (vehicleType) {
      case PremiumVehicleType.chopper:
        return 'https://example.com/logos/skytour.png';
      case PremiumVehicleType.privateJet:
        return 'https://example.com/logos/elite-aviation.png';
      case PremiumVehicleType.cruise:
        return 'https://example.com/logos/ocean-luxury.png';
    }
  }
}

// Notifier for managing boarding passes
class BoardingPassNotifier extends StateNotifier<AsyncValue<List<BoardingPass>>> {
  BoardingPassNotifier() : super(const AsyncValue.loading()) {
    _loadBoardingPasses();
    _setupRealtimeSubscription();
  }

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  Future<void> _loadBoardingPasses() async {
    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Query boarding passes from Supabase
      final response = await _supabase
          .from('boarding_passes')
          .select()
          .eq('user_id', user.id)
          .order('departure_time', ascending: false);

      final boardingPasses = (response as List<dynamic>)
          .map((json) => BoardingPass.fromJson(json))
          .toList();

      state = AsyncValue.data(boardingPasses);
    } catch (error) {
      // For development, create mock data if Supabase fails
      debugPrint('Failed to load boarding passes from Supabase: $error');
      await _loadMockBoardingPasses();
    }
  }

  Future<void> _loadMockBoardingPasses() async {
    // Get actual user name
    final user = _supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 
                     user?.email?.split('@')[0] ?? 
                     'Passenger';
    
    // Mock boarding passes for development
    final mockPasses = [
      BoardingPass(
        id: '1',
        rideEventId: 'ride_123',
        passengerName: userName,
        bookingId: 'BP1234567890',
        vehicleType: PremiumVehicleType.privateJet,
        destination: 'Mombasa',
        origin: 'Nairobi',
        departureTime: DateTime.now().add(const Duration(days: 1)),
        arrivalTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
        operatorName: 'Elite Aviation',
        operatorLogo: '',
        qrCode: 'BOARDING_PASS:ride_123:1234567890',
        status: BoardingPassStatus.upcoming,
        createdAt: DateTime.now(),
        seatNumber: '1A',
        gate: 'G12',
        terminal: 'Terminal 2',
        fare: 125000.0,
      ),
      BoardingPass(
        id: '2',
        rideEventId: 'ride_456',
        passengerName: userName,
        bookingId: 'BP9876543210',
        vehicleType: PremiumVehicleType.chopper,
        destination: 'Kisumu',
        origin: 'Nairobi',
        departureTime: DateTime.now().subtract(const Duration(days: 2)),
        arrivalTime: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
        operatorName: 'SkyTour Helicopters',
        operatorLogo: '',
        qrCode: 'BOARDING_PASS:ride_456:9876543210',
        status: BoardingPassStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        seatNumber: '2B',
        gate: 'H5',
        terminal: 'Helipad A',
        fare: 45000.0,
      ),
    ];

    state = AsyncValue.data(mockPasses);
  }

  Future<BoardingPass?> createBoardingPass({
    required String rideEventId,
    required String passengerName,
    required PremiumVehicleType vehicleType,
    required String destination,
    String? origin,
    required DateTime departureTime,
    DateTime? arrivalTime,
    String? seatNumber,
    String? gate,
    String? terminal,
    double? fare,
    List<PassengerDetail>? passengerDetails,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ BOARDING PASS ERROR: User not authenticated');
        throw Exception('User not authenticated');
      }

      debugPrint('🎫 Creating boarding pass for user: ${user.id}');
      
      final boardingPass = BoardingPass(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rideEventId: rideEventId,
        passengerName: passengerName,
        bookingId: BoardingPassService.generateBookingId(),
        vehicleType: vehicleType,
        destination: destination,
        origin: origin,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        operatorName: BoardingPassService.getOperatorName(vehicleType),
        operatorLogo: BoardingPassService.getOperatorLogo(vehicleType),
        qrCode: BoardingPassService.generateQRCode(rideEventId),
        status: BoardingPassStatus.upcoming,
        createdAt: DateTime.now(),
        seatNumber: seatNumber,
        gate: gate,
        terminal: terminal,
        fare: fare,
      );

      // Insert into Supabase
      final data = boardingPass.toJson();
      data['user_id'] = user.id; // Add user ID for the database
      
      // Add passenger details if available
      if (passengerDetails != null && passengerDetails.isNotEmpty) {
        data['passenger_details'] = jsonEncode(
          passengerDetails.map((p) => {
            'name': p.name,
            'email': p.email,
            'phone': p.phone,
          }).toList(),
        );
        debugPrint('👥 Added ${passengerDetails.length} passenger details to booking');
      }

      debugPrint('🚀 Attempting to insert boarding pass data:');
      debugPrint('📝 Data keys: ${data.keys.join(', ')}');
      debugPrint('🎯 Booking ID: ${data['booking_id']}');
      debugPrint('✈️ Vehicle Type: ${data['vehicle_type']}');

      try {
        final response = await _supabase.from('boarding_passes').insert(data).select();
        debugPrint('✅ Successfully inserted boarding pass to Supabase');
        debugPrint('📄 Supabase response: $response');
      } catch (e) {
        debugPrint('❌ SUPABASE INSERT ERROR: $e');
        debugPrint('🔍 Error type: ${e.runtimeType}');
        
        // Try to get more specific error information
        if (e.toString().contains('duplicate key')) {
          debugPrint('🚫 Duplicate booking ID detected');
          throw Exception('Booking ID already exists. Please try again.');
        } else if (e.toString().contains('violates check constraint')) {
          debugPrint('🚫 Data validation error');
          throw Exception('Invalid data provided. Please check your input.');
        } else if (e.toString().contains('relation "boarding_passes" does not exist')) {
          debugPrint('🚫 Table does not exist');
          throw Exception('Database table not found. Please contact support.');
        } else {
          debugPrint('🚫 Generic database error');
          throw Exception('Failed to save booking: ${e.toString()}');
        }
      }

      // Update local state
      final currentPasses = state.asData?.value ?? [];
      state = AsyncValue.data([boardingPass, ...currentPasses]);

      debugPrint('✅ Boarding pass created successfully!');
      return boardingPass;
    } catch (error, stackTrace) {
      debugPrint('❌ CRITICAL ERROR creating boarding pass: $error');
      debugPrint('📊 Stack trace: $stackTrace');
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<void> updateBoardingPassStatus(String id, BoardingPassStatus status) async {
    try {
      // Update in Supabase
      try {
        await _supabase
            .from('boarding_passes')
            .update({'status': status.name, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', id);
      } catch (e) {
        debugPrint('Failed to update boarding pass status in Supabase: $e');
      }

      // Update local state
      final currentPasses = state.asData?.value ?? [];
      final updatedPasses = currentPasses.map((pass) {
        if (pass.id == id) {
          return pass.copyWith(status: status, updatedAt: DateTime.now());
        }
        return pass;
      }).toList();

      state = AsyncValue.data(updatedPasses);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void refresh() {
    _loadBoardingPasses();
  }
  
  // Setup real-time subscription for boarding pass updates
  void _setupRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    debugPrint('🔔 Setting up real-time subscription for boarding passes');
    
    _realtimeChannel = _supabase
        .channel('boarding_passes_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'boarding_passes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint('🔄 Boarding pass update received: ${payload.eventType}');
            debugPrint('📦 Payload: ${payload.newRecord}');
            
            // Reload boarding passes when any change occurs
            _loadBoardingPasses();
          },
        )
        .subscribe();
  }
  
  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

// Provider instances
final boardingPassProvider = StateNotifierProvider<BoardingPassNotifier, AsyncValue<List<BoardingPass>>>(
  (ref) => BoardingPassNotifier(),
);

// Helper providers
final activeBoardingPassesProvider = Provider<List<BoardingPass>>((ref) {
  final boardingPasses = ref.watch(boardingPassProvider);
  
  return boardingPasses.when(
    data: (passes) => passes.where((pass) => pass.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final pastBoardingPassesProvider = Provider<List<BoardingPass>>((ref) {
  final boardingPasses = ref.watch(boardingPassProvider);
  
  return boardingPasses.when(
    data: (passes) => passes.where((pass) => pass.isPast).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final nextBoardingPassProvider = Provider<BoardingPass?>((ref) {
  final activePasses = ref.watch(activeBoardingPassesProvider);
  
  if (activePasses.isEmpty) return null;
  
  // Sort by departure time and return the next upcoming one
  final sortedPasses = [...activePasses];
  sortedPasses.sort((a, b) => a.departureTime.compareTo(b.departureTime));
  
  return sortedPasses.first;
});

// Provider for a specific boarding pass
final boardingPassByIdProvider = Provider.family<BoardingPass?, String>((ref, id) {
  final boardingPasses = ref.watch(boardingPassProvider);
  
  return boardingPasses.when(
    data: (passes) => passes.cast<BoardingPass?>().firstWhere(
      (pass) => pass?.id == id,
      orElse: () => null,
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});

// Passenger detail model
class PassengerDetail {
  final String name;
  final String? email;
  final String? phone;
  
  const PassengerDetail({
    required this.name,
    this.email,
    this.phone,
  });
  
  PassengerDetail copyWith({
    String? name,
    String? email,
    String? phone,
  }) {
    return PassengerDetail(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}

// State for premium booking form
class PremiumBookingState {
  final PremiumVehicleType? selectedVehicleType;
  final String? origin;
  final String? destination;
  final DateTime? departureDate;
  final TimeOfDay? departureTime;
  final DateTime? arrivalDate;
  final TimeOfDay? arrivalTime;
  final int passengers;
  final String? passengerName; // Kept for backward compatibility
  final List<PassengerDetail> passengerDetails;
  final bool isLoading;
  final String? error;

  const PremiumBookingState({
    this.selectedVehicleType,
    this.origin,
    this.destination,
    this.departureDate,
    this.departureTime,
    this.arrivalDate,
    this.arrivalTime,
    this.passengers = 1,
    this.passengerName,
    this.passengerDetails = const [],
    this.isLoading = false,
    this.error,
  });

  PremiumBookingState copyWith({
    PremiumVehicleType? selectedVehicleType,
    String? origin,
    String? destination,
    DateTime? departureDate,
    TimeOfDay? departureTime,
    DateTime? arrivalDate,
    TimeOfDay? arrivalTime,
    int? passengers,
    String? passengerName,
    List<PassengerDetail>? passengerDetails,
    bool? isLoading,
    String? error,
  }) {
    return PremiumBookingState(
      selectedVehicleType: selectedVehicleType ?? this.selectedVehicleType,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureDate: departureDate ?? this.departureDate,
      departureTime: departureTime ?? this.departureTime,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      passengers: passengers ?? this.passengers,
      passengerName: passengerName ?? this.passengerName,
      passengerDetails: passengerDetails ?? this.passengerDetails,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  DateTime? get departureDateTime {
    if (departureDate == null || departureTime == null) return null;
    return DateTime(
      departureDate!.year,
      departureDate!.month,
      departureDate!.day,
      departureTime!.hour,
      departureTime!.minute,
    );
  }

  DateTime? get arrivalDateTime {
    if (arrivalDate == null || arrivalTime == null) return null;
    return DateTime(
      arrivalDate!.year,
      arrivalDate!.month,
      arrivalDate!.day,
      arrivalTime!.hour,
      arrivalTime!.minute,
    );
  }

  bool get canBook {
    // Check if all required passenger details are filled
    final hasAllPassengerDetails = passengerDetails.length == passengers &&
        passengerDetails.every((p) => p.name.trim().length >= 2);
    
    debugPrint('🔍 canBook check:');
    debugPrint('  - selectedVehicleType: $selectedVehicleType');
    debugPrint('  - origin: $origin');
    debugPrint('  - destination: $destination');
    debugPrint('  - departureDate: $departureDate');
    debugPrint('  - departureTime: $departureTime');
    debugPrint('  - passengers: $passengers, details count: ${passengerDetails.length}');
    debugPrint('  - passenger names: ${passengerDetails.map((p) => "${p.name} (${p.name.trim().length} chars)").join(", ")}');
    debugPrint('  - hasAllPassengerDetails: $hasAllPassengerDetails');
    
    return selectedVehicleType != null &&
           origin != null &&
           destination != null &&
           departureDate != null &&
           departureTime != null &&
           hasAllPassengerDetails;
  }

  double? get estimatedFare {
    if (selectedVehicleType == null || origin == null || destination == null) {
      return null;
    }

    // Simple fare calculation - in reality this would use distance/route calculation
    switch (selectedVehicleType!) {
      case PremiumVehicleType.chopper:
        return 45000.0 + (passengers * 5000.0);
      case PremiumVehicleType.privateJet:
        return 125000.0 + (passengers * 10000.0);
      case PremiumVehicleType.cruise:
        return 85000.0 + (passengers * 15000.0);
    }
  }
}

// Notifier for premium booking
class PremiumBookingNotifier extends StateNotifier<PremiumBookingState> {
  PremiumBookingNotifier() : super(
    const PremiumBookingState(
      passengerDetails: [PassengerDetail(name: '')],
    ),
  );

  void setVehicleType(PremiumVehicleType type) {
    state = state.copyWith(selectedVehicleType: type, error: null);
  }

  void setOrigin(String origin) {
    state = state.copyWith(origin: origin, error: null);
  }

  void setDestination(String destination) {
    state = state.copyWith(destination: destination, error: null);
  }

  void setDepartureDate(DateTime date) {
    state = state.copyWith(departureDate: date, error: null);
  }

  void setDepartureTime(TimeOfDay time) {
    state = state.copyWith(departureTime: time, error: null);
  }

  void setArrivalDate(DateTime date) {
    state = state.copyWith(arrivalDate: date, error: null);
  }

  void setArrivalTime(TimeOfDay time) {
    state = state.copyWith(arrivalTime: time, error: null);
  }

  void setPassengers(int count) {
    // Initialize or adjust passenger details list when count changes
    final currentDetails = List<PassengerDetail>.from(state.passengerDetails);
    
    if (count > currentDetails.length) {
      // Add empty passenger details
      for (int i = currentDetails.length; i < count; i++) {
        currentDetails.add(const PassengerDetail(name: ''));
      }
    } else if (count < currentDetails.length) {
      // Remove extra passenger details
      currentDetails.removeRange(count, currentDetails.length);
    }
    
    state = state.copyWith(
      passengers: count,
      passengerDetails: currentDetails,
      error: null,
    );
  }

  void setPassengerName(String name) {
    state = state.copyWith(passengerName: name, error: null);
  }
  
  void updatePassengerDetail(int index, {
    String? name,
    String? email,
    String? phone,
  }) {
    if (index < 0 || index >= state.passengers) return;
    
    final updatedDetails = List<PassengerDetail>.from(state.passengerDetails);
    
    // Ensure the list has enough entries
    while (updatedDetails.length <= index) {
      updatedDetails.add(const PassengerDetail(name: ''));
    }
    
    final currentDetail = updatedDetails[index];
    
    updatedDetails[index] = PassengerDetail(
      name: name ?? currentDetail.name,
      email: email ?? currentDetail.email,
      phone: phone ?? currentDetail.phone,
    );
    
    debugPrint('👤 Updated passenger $index: name="${updatedDetails[index].name}" (${updatedDetails[index].name.trim().length} chars)');
    debugPrint('✅ Can book: ${state.copyWith(passengerDetails: updatedDetails).canBook}');
    
    state = state.copyWith(passengerDetails: updatedDetails, error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const PremiumBookingState();
  }

  Future<BoardingPass?> confirmBooking([String? overridePassengerName]) async {
    if (!state.canBook) {
      state = state.copyWith(error: 'Please fill all required fields');
      return null;
    }

    final departureDateTime = state.departureDateTime!;
    final now = DateTime.now();
    
    if (departureDateTime.isBefore(now.add(const Duration(hours: 2)))) {
      state = state.copyWith(error: 'Departure must be at least 2 hours in advance');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Simulate booking API call
      await Future.delayed(const Duration(seconds: 2));

      // Generate ride event ID
      final rideEventId = 'ride_${DateTime.now().millisecondsSinceEpoch}';

      // Create boarding pass (this would typically be done on the backend)
      final boardingPassNotifier = ref.read(boardingPassProvider.notifier);
      
      // Use first passenger name or override
      final passengerName = overridePassengerName ?? 
                            (state.passengerDetails.isNotEmpty ? state.passengerDetails[0].name : state.passengerName ?? '');
      
      final boardingPass = await boardingPassNotifier.createBoardingPass(
        rideEventId: rideEventId,
        passengerName: passengerName,
        vehicleType: state.selectedVehicleType!,
        destination: state.destination!,
        origin: state.origin!,
        departureTime: departureDateTime,
        arrivalTime: state.arrivalDateTime,
        fare: state.estimatedFare,
        passengerDetails: state.passengerDetails,
      );

      state = state.copyWith(isLoading: false);
      return boardingPass;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to confirm booking: $e',
      );
      return null;
    }
  }

  late Ref ref;
  
  void setRef(Ref ref) {
    this.ref = ref;
  }
}

// Premium booking provider
final premiumBookingProvider = StateNotifierProvider<PremiumBookingNotifier, PremiumBookingState>(
  (ref) {
    final notifier = PremiumBookingNotifier();
    notifier.setRef(ref);
    return notifier;
  },
);