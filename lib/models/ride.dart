/// Comprehensive Ride model for Socket.IO integration
class Ride {
  // Basic Info
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String? passengerImage;
  
  // Driver Info
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicle;
  final String? driverVehicleNumber;
  final double? driverRating;
  final String? driverImage;
  
  // Location Info
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationAddress;
  
  // Trip Details
  final String? distance;
  final String? duration;
  final String? fare;
  final String? notes;
  
  // Route Data
  final String? routePolyline;
  final String? driverToPickupPolyline;
  final String? driverToPickupDistance;
  final String? driverToPickupDuration;
  final String? estimatedArrival;
  
  // Driver Location (real-time)
  final double? driverLatitude;
  final double? driverLongitude;
  
  // Status & Timestamps
  final String status; // requested, submitted, accepted, started, completed, cancelled
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  
  // Rating
  final int? rating;
  final String? feedback;
  
  // Legacy fields for backward compatibility
  final bool isScheduled;
  final DateTime? scheduledDateTime;

  const Ride({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    this.passengerImage,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverVehicle,
    this.driverVehicleNumber,
    this.driverRating,
    this.driverImage,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationAddress,
    this.distance,
    this.duration,
    this.fare,
    this.notes,
    this.routePolyline,
    this.driverToPickupPolyline,
    this.driverToPickupDistance,
    this.driverToPickupDuration,
    this.estimatedArrival,
    this.driverLatitude,
    this.driverLongitude,
    required this.status,
    required this.requestedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.rating,
    this.feedback,
    this.isScheduled = false,
    this.scheduledDateTime,
  });

  // Backward compatibility properties
  String get pickupLocation => pickupAddress;
  String get dropoffLocation => destinationAddress;
  String get driverCar => driverVehicle ?? 'TBD';
  DateTime get dateTime => requestedAt;

  // Copy with method
  Ride copyWith({
    String? id,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? passengerImage,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverVehicle,
    String? driverVehicleNumber,
    double? driverRating,
    String? driverImage,
    double? pickupLatitude,
    double? pickupLongitude,
    String? pickupAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationAddress,
    String? distance,
    String? duration,
    String? fare,
    String? notes,
    String? routePolyline,
    String? driverToPickupPolyline,
    String? driverToPickupDistance,
    String? driverToPickupDuration,
    String? estimatedArrival,
    double? driverLatitude,
    double? driverLongitude,
    String? status,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    int? rating,
    String? feedback,
    bool? isScheduled,
    DateTime? scheduledDateTime,
  }) {
    return Ride(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerImage: passengerImage ?? this.passengerImage,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverVehicle: driverVehicle ?? this.driverVehicle,
      driverVehicleNumber: driverVehicleNumber ?? this.driverVehicleNumber,
      driverRating: driverRating ?? this.driverRating,
      driverImage: driverImage ?? this.driverImage,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      fare: fare ?? this.fare,
      notes: notes ?? this.notes,
      routePolyline: routePolyline ?? this.routePolyline,
      driverToPickupPolyline: driverToPickupPolyline ?? this.driverToPickupPolyline,
      driverToPickupDistance: driverToPickupDistance ?? this.driverToPickupDistance,
      driverToPickupDuration: driverToPickupDuration ?? this.driverToPickupDuration,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
    );
  }

  // Factory constructor for creating scheduled rides
  factory Ride.scheduled({
    required String id,
    required String pickupLocation,
    required String dropoffLocation,
    required DateTime scheduledDateTime,
    String driverName = 'TBD',
    String driverCar = 'TBD',
    double fare = 0.0,
  }) {
    return Ride(
      id: id,
      passengerId: 'temp',
      passengerName: 'Passenger',
      passengerPhone: '',
      pickupLatitude: 0,
      pickupLongitude: 0,
      pickupAddress: pickupLocation,
      destinationLatitude: 0,
      destinationLongitude: 0,
      destinationAddress: dropoffLocation,
      driverName: driverName,
      driverVehicle: driverCar,
      fare: fare.toStringAsFixed(2),
      status: 'scheduled',
      requestedAt: DateTime.now(),
      isScheduled: true,
      scheduledDateTime: scheduledDateTime,
    );
  }

  // Factory constructor from socket data
  factory Ride.fromSocketData(Map<String, dynamic> data) {
    return Ride(
      id: data['ride_id'] ?? data['id'] ?? '',
      passengerId: data['passenger_id'] ?? '',
      passengerName: data['passenger_name'] ?? '',
      passengerPhone: data['passenger_phone'] ?? '',
      passengerImage: data['passenger_image'],
      driverId: data['driver_id'],
      driverName: data['driver_name'],
      driverPhone: data['driver_phone'],
      driverVehicle: data['driver_vehicle'],
      driverVehicleNumber: data['driver_vehicle_number'],
      driverRating: _toDouble(data['driver_rating']),
      driverImage: data['driver_image'],
      pickupLatitude: _toDouble(data['pickup_latitude']) ?? 0,
      pickupLongitude: _toDouble(data['pickup_longitude']) ?? 0,
      pickupAddress: data['pickup_address'] ?? '',
      destinationLatitude: _toDouble(data['destination_latitude']) ?? 0,
      destinationLongitude: _toDouble(data['destination_longitude']) ?? 0,
      destinationAddress: data['destination_address'] ?? '',
      distance: data['distance']?.toString(),
      duration: data['duration']?.toString(),
      fare: data['fare']?.toString() ?? data['estimated_fare']?.toString(),
      notes: data['notes'],
      routePolyline: data['route_polyline'],
      driverToPickupPolyline: data['driver_to_pickup_polyline'],
      driverToPickupDistance: data['driver_to_pickup_distance'],
      driverToPickupDuration: data['driver_to_pickup_duration'],
      estimatedArrival: data['estimated_arrival'],
      driverLatitude: _toDouble(data['driver_latitude']),
      driverLongitude: _toDouble(data['driver_longitude']),
      status: data['status'] ?? 'requested',
      requestedAt: _parseDateTime(data['timestamp']) ?? _parseDateTime(data['requested_at']) ?? DateTime.now(),
      acceptedAt: _parseDateTime(data['accepted_at']),
      startedAt: _parseDateTime(data['started_at']),
      completedAt: _parseDateTime(data['completed_at']),
      cancelledAt: _parseDateTime(data['cancelled_at']),
      rating: data['rating'],
      feedback: data['feedback'],
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}


