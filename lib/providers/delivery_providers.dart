import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../models/delivery.dart';

// Service for calculating delivery costs and generating tracking numbers
class DeliveryService {
  static String generateTrackingNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'TT${timestamp.toString().substring(8)}$random';
  }

  static double calculateDeliveryCost({
    required PackageDetails package,
    required DeliveryVehicleType vehicleType,
    required DeliveryPriority priority,
    required double distance, // in km
  }) {
    double baseCost = 0;
    
    // Base cost calculation based on vehicle type
    switch (vehicleType) {
      case DeliveryVehicleType.cargoPlane:
        // Air freight: cost per kg per km
        baseCost = package.chargeableWeight * distance * 0.5;
        break;
      case DeliveryVehicleType.cargoShip:
        // Sea freight: cost per cubic meter per km
        baseCost = package.volume * distance * 200;
        break;
    }

    // Apply priority multiplier
    baseCost *= priority.multiplier;

    // Special handling fees
    if (package.isFragile) baseCost += 500;
    if (package.requiresRefrigeration) baseCost += 1000;
    if (package.type == PackageType.hazardous) baseCost += 2000;

    // Minimum cost
    return baseCost < 1000 ? 1000 : baseCost;
  }

  static DateTime calculateEstimatedDelivery({
    required DeliveryVehicleType vehicleType,
    required DeliveryPriority priority,
    required double distance,
  }) {
    final now = DateTime.now();
    int hours = 0;

    switch (vehicleType) {
      case DeliveryVehicleType.cargoPlane:
        switch (priority) {
          case DeliveryPriority.sameDay:
            hours = 6;
            break;
          case DeliveryPriority.overnight:
            hours = 24;
            break;
          case DeliveryPriority.express:
            hours = 48;
            break;
          case DeliveryPriority.standard:
            hours = 120; // 5 days
            break;
        }
        break;
      case DeliveryVehicleType.cargoShip:
        switch (priority) {
          case DeliveryPriority.sameDay:
            hours = 168; // 7 days (fastest sea freight)
            break;
          case DeliveryPriority.overnight:
            hours = 240; // 10 days
            break;
          case DeliveryPriority.express:
            hours = 336; // 14 days
            break;
          case DeliveryPriority.standard:
            hours = 504; // 21 days
            break;
        }
        break;
    }

    return now.add(Duration(hours: hours));
  }
}

// State for delivery booking form
class DeliveryBookingState {
  final ContactDetails? sender;
  final ContactDetails? recipient;
  final PackageDetails? package;
  final DeliveryVehicleType? selectedVehicleType;
  final DeliveryPriority selectedPriority;
  final DateTime? pickupDate;
  final TimeOfDay? pickupTime;
  final String? notes;
  final bool isLoading;
  final String? error;

  const DeliveryBookingState({
    this.sender,
    this.recipient,
    this.package,
    this.selectedVehicleType,
    this.selectedPriority = DeliveryPriority.standard,
    this.pickupDate,
    this.pickupTime,
    this.notes,
    this.isLoading = false,
    this.error,
  });

  DeliveryBookingState copyWith({
    ContactDetails? sender,
    ContactDetails? recipient,
    PackageDetails? package,
    DeliveryVehicleType? selectedVehicleType,
    DeliveryPriority? selectedPriority,
    DateTime? pickupDate,
    TimeOfDay? pickupTime,
    String? notes,
    bool? isLoading,
    String? error,
  }) {
    return DeliveryBookingState(
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      package: package ?? this.package,
      selectedVehicleType: selectedVehicleType ?? this.selectedVehicleType,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTime: pickupTime ?? this.pickupTime,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get canBook {
    return sender != null &&
           recipient != null &&
           package != null &&
           selectedVehicleType != null &&
           pickupDate != null &&
           pickupTime != null;
  }

  double? get estimatedCost {
    if (sender == null || recipient == null || package == null || selectedVehicleType == null) {
      return null;
    }

    // Simple distance calculation (in reality would use proper geolocation)
    final distance = _calculateDistance(sender!.city, recipient!.city);
    
    return DeliveryService.calculateDeliveryCost(
      package: package!,
      vehicleType: selectedVehicleType!,
      priority: selectedPriority,
      distance: distance,
    );
  }

  DateTime? get estimatedDelivery {
    if (sender == null || recipient == null || selectedVehicleType == null) {
      return null;
    }

    final distance = _calculateDistance(sender!.city, recipient!.city);
    
    return DeliveryService.calculateEstimatedDelivery(
      vehicleType: selectedVehicleType!,
      priority: selectedPriority,
      distance: distance,
    );
  }

  double _calculateDistance(String fromCity, String toCity) {
    // Mock distance calculation - in reality would use proper geolocation
    final distances = {
      'Nairobi-Mombasa': 480.0,
      'Nairobi-Kisumu': 350.0,
      'Nairobi-Eldoret': 310.0,
      'Mombasa-Kisumu': 650.0,
      'Nairobi-Nakuru': 160.0,
    };
    
    final key1 = '$fromCity-$toCity';
    final key2 = '$toCity-$fromCity';
    
    return distances[key1] ?? distances[key2] ?? 500.0; // Default 500km
  }
}

// Notifier for delivery booking
class DeliveryBookingNotifier extends StateNotifier<DeliveryBookingState> {
  DeliveryBookingNotifier() : super(const DeliveryBookingState());

  void setSender(ContactDetails sender) {
    state = state.copyWith(sender: sender, error: null);
  }

  void setRecipient(ContactDetails recipient) {
    state = state.copyWith(recipient: recipient, error: null);
  }

  void setPackage(PackageDetails package) {
    state = state.copyWith(package: package, error: null);
  }

  void setVehicleType(DeliveryVehicleType type) {
    state = state.copyWith(selectedVehicleType: type, error: null);
  }

  void setPriority(DeliveryPriority priority) {
    state = state.copyWith(selectedPriority: priority, error: null);
  }

  void setPickupDate(DateTime date) {
    state = state.copyWith(pickupDate: date, error: null);
  }

  void setPickupTime(TimeOfDay time) {
    state = state.copyWith(pickupTime: time, error: null);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes, error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const DeliveryBookingState();
  }

  Future<DeliveryBooking?> confirmBooking() async {
    if (!state.canBook) {
      state = state.copyWith(error: 'Please fill all required fields');
      return null;
    }

    final pickupDateTime = DateTime(
      state.pickupDate!.year,
      state.pickupDate!.month,
      state.pickupDate!.day,
      state.pickupTime!.hour,
      state.pickupTime!.minute,
    );

    final now = DateTime.now();
    if (pickupDateTime.isBefore(now.add(const Duration(hours: 2)))) {
      state = state.copyWith(error: 'Pickup must be at least 2 hours in advance');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Simulate booking API call
      await Future.delayed(const Duration(seconds: 2));

      final trackingNumber = DeliveryService.generateTrackingNumber();
      final totalCost = state.estimatedCost!;
      final estimatedDelivery = state.estimatedDelivery!;

      final booking = DeliveryBooking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        trackingNumber: trackingNumber,
        sender: state.sender!,
        recipient: state.recipient!,
        package: state.package!,
        vehicleType: state.selectedVehicleType!,
        priority: state.selectedPriority,
        status: DeliveryStatus.pending,
        createdAt: DateTime.now(),
        estimatedPickupTime: pickupDateTime,
        estimatedDeliveryTime: estimatedDelivery,
        totalCost: totalCost,
        notes: state.notes,
        updates: [
          DeliveryUpdate(
            id: '1',
            deliveryId: DateTime.now().millisecondsSinceEpoch.toString(),
            status: DeliveryStatus.pending,
            timestamp: DateTime.now(),
            message: 'Delivery booking created',
            location: state.sender!.city,
          ),
        ],
      );

      // Add to delivery list
      final deliveryListNotifier = ref?.read(deliveryListProvider.notifier);
      deliveryListNotifier?.addDelivery(booking);

      state = state.copyWith(isLoading: false);
      return booking;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to confirm booking: $e',
      );
      return null;
    }
  }

  Ref? ref;

  void setRef(Ref ref) {
    this.ref = ref;
  }
}

// Notifier for managing delivery list
class DeliveryListNotifier extends StateNotifier<AsyncValue<List<DeliveryBooking>>> {
  DeliveryListNotifier() : super(const AsyncValue.loading()) {
    _loadDeliveries();
  }

  final _supabase = Supabase.instance.client;

  Future<void> _loadDeliveries() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // In a real app, this would load from Supabase
      // For now, create mock data
      await _loadMockDeliveries();
    } catch (error, stackTrace) {
      debugPrint('Failed to load deliveries: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _loadMockDeliveries() async {
    // Get actual user name
    final user = _supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 
                     user?.email?.split('@')[0] ?? 
                     'User';
    final userEmail = user?.email ?? 'user@example.com';
    
    // Mock delivery data
    final mockDeliveries = [
      DeliveryBooking(
        id: '1',
        trackingNumber: 'TT1234567890',
        sender: ContactDetails(
          name: userName,
          phone: '+254123456789',
          email: userEmail,
          address: '123 Main St',
          city: 'Nairobi',
          state: 'Nairobi',
          postalCode: '00100',
          country: 'Kenya',
          company: 'ABC Corp',
        ),
        recipient: const ContactDetails(
          name: 'Jane Smith',
          phone: '+254987654321',
          email: 'jane@example.com',
          address: '456 Oak Ave',
          city: 'Mombasa',
          state: 'Mombasa',
          postalCode: '80100',
          country: 'Kenya',
        ),
        package: const PackageDetails(
          description: 'Electronics shipment',
          type: PackageType.electronics,
          weight: 5.0,
          length: 30.0,
          width: 20.0,
          height: 15.0,
          declaredValue: 50000.0,
          isFragile: true,
        ),
        vehicleType: DeliveryVehicleType.cargoPlane,
        priority: DeliveryPriority.express,
        status: DeliveryStatus.inTransit,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        estimatedPickupTime: DateTime.now().subtract(const Duration(days: 1)),
        estimatedDeliveryTime: DateTime.now().add(const Duration(hours: 6)),
        totalCost: 8500.0,
        updates: [
          DeliveryUpdate(
            id: '1',
            deliveryId: '1',
            status: DeliveryStatus.confirmed,
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
            message: 'Booking confirmed',
            location: 'Nairobi',
          ),
          DeliveryUpdate(
            id: '2',
            deliveryId: '1',
            status: DeliveryStatus.pickedUp,
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            message: 'Package picked up',
            location: 'Nairobi',
          ),
          DeliveryUpdate(
            id: '3',
            deliveryId: '1',
            status: DeliveryStatus.inTransit,
            timestamp: DateTime.now().subtract(const Duration(hours: 12)),
            message: 'In transit to destination',
            location: 'Jomo Kenyatta International Airport',
          ),
        ],
      ),
    ];

    state = AsyncValue.data(mockDeliveries);
  }

  void addDelivery(DeliveryBooking delivery) {
    final currentDeliveries = state.asData?.value ?? [];
    state = AsyncValue.data([delivery, ...currentDeliveries]);
  }

  Future<void> updateDeliveryStatus(String deliveryId, DeliveryStatus status, String message) async {
    final currentDeliveries = state.asData?.value ?? [];
    final updatedDeliveries = currentDeliveries.map((delivery) {
      if (delivery.id == deliveryId) {
        final update = DeliveryUpdate(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          deliveryId: deliveryId,
          status: status,
          timestamp: DateTime.now(),
          message: message,
        );
        
        return delivery.copyWith(
          status: status,
          updates: [...delivery.updates, update],
        );
      }
      return delivery;
    }).toList();

    state = AsyncValue.data(updatedDeliveries);
  }

  void refresh() {
    _loadDeliveries();
  }
}

// Provider instances
final deliveryBookingProvider = StateNotifierProvider<DeliveryBookingNotifier, DeliveryBookingState>(
  (ref) {
    final notifier = DeliveryBookingNotifier();
    notifier.setRef(ref);
    return notifier;
  },
);

final deliveryListProvider = StateNotifierProvider<DeliveryListNotifier, AsyncValue<List<DeliveryBooking>>>(
  (ref) => DeliveryListNotifier(),
);

// Helper providers
final activeDeliveriesProvider = Provider<List<DeliveryBooking>>((ref) {
  final deliveries = ref.watch(deliveryListProvider);
  
  return deliveries.when(
    data: (list) => list.where((delivery) => delivery.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final completedDeliveriesProvider = Provider<List<DeliveryBooking>>((ref) {
  final deliveries = ref.watch(deliveryListProvider);
  
  return deliveries.when(
    data: (list) => list.where((delivery) => !delivery.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for a specific delivery
final deliveryByIdProvider = Provider.family<DeliveryBooking?, String>((ref, id) {
  final deliveries = ref.watch(deliveryListProvider);
  
  return deliveries.when(
    data: (list) => list.cast<DeliveryBooking?>().firstWhere(
      (delivery) => delivery?.id == id,
      orElse: () => null,
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});