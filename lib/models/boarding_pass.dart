enum BoardingPassStatus {
  upcoming,
  boarding,
  departed,
  completed,
  cancelled,
}

enum PremiumVehicleType {
  chopper,
  privateJet,
  cruise,
}

class BoardingPass {
  final String id;
  final String rideEventId;
  final String passengerName;
  final String bookingId;
  final PremiumVehicleType vehicleType;
  final String destination;
  final String? origin;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final String operatorName;
  final String operatorLogo;
  final String qrCode;
  final BoardingPassStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? seatNumber;
  final String? gate;
  final String? terminal;
  final double? fare;

  const BoardingPass({
    required this.id,
    required this.rideEventId,
    required this.passengerName,
    required this.bookingId,
    required this.vehicleType,
    required this.destination,
    this.origin,
    required this.departureTime,
    this.arrivalTime,
    required this.operatorName,
    required this.operatorLogo,
    required this.qrCode,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.seatNumber,
    this.gate,
    this.terminal,
    this.fare,
  });

  // Factory constructor for creating from JSON (Supabase)
  factory BoardingPass.fromJson(Map<String, dynamic> json) {
    return BoardingPass(
      id: json['id'],
      rideEventId: json['ride_event_id'],
      passengerName: json['passenger_name'],
      bookingId: json['booking_id'],
      vehicleType: PremiumVehicleType.values.firstWhere(
        (e) => e.name == json['vehicle_type'],
        orElse: () => PremiumVehicleType.chopper,
      ),
      destination: json['destination'],
      origin: json['origin'],
      departureTime: DateTime.parse(json['departure_time']),
      arrivalTime: json['arrival_time'] != null 
          ? DateTime.parse(json['arrival_time']) 
          : null,
      operatorName: json['operator_name'],
      operatorLogo: json['operator_logo'] ?? '',
      qrCode: json['qr_code'],
      status: BoardingPassStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BoardingPassStatus.upcoming,
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      seatNumber: json['seat_number'],
      gate: json['gate'],
      terminal: json['terminal'],
      fare: json['fare']?.toDouble(),
    );
  }

  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_event_id': rideEventId,
      'passenger_name': passengerName,
      'booking_id': bookingId,
      'vehicle_type': vehicleType.name,
      'destination': destination,
      'origin': origin,
      'departure_time': departureTime.toIso8601String(),
      'arrival_time': arrivalTime?.toIso8601String(),
      'operator_name': operatorName,
      'operator_logo': operatorLogo,
      'qr_code': qrCode,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'seat_number': seatNumber,
      'gate': gate,
      'terminal': terminal,
      'fare': fare,
    };
  }

  // Copy with method
  BoardingPass copyWith({
    String? id,
    String? rideEventId,
    String? passengerName,
    String? bookingId,
    PremiumVehicleType? vehicleType,
    String? destination,
    String? origin,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? operatorName,
    String? operatorLogo,
    String? qrCode,
    BoardingPassStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? seatNumber,
    String? gate,
    String? terminal,
    double? fare,
  }) {
    return BoardingPass(
      id: id ?? this.id,
      rideEventId: rideEventId ?? this.rideEventId,
      passengerName: passengerName ?? this.passengerName,
      bookingId: bookingId ?? this.bookingId,
      vehicleType: vehicleType ?? this.vehicleType,
      destination: destination ?? this.destination,
      origin: origin ?? this.origin,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      operatorName: operatorName ?? this.operatorName,
      operatorLogo: operatorLogo ?? this.operatorLogo,
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      seatNumber: seatNumber ?? this.seatNumber,
      gate: gate ?? this.gate,
      terminal: terminal ?? this.terminal,
      fare: fare ?? this.fare,
    );
  }

  // Helper methods
  String get vehicleTypeDisplayName {
    switch (vehicleType) {
      case PremiumVehicleType.chopper:
        return 'Helicopter';
      case PremiumVehicleType.privateJet:
        return 'Private Jet';
      case PremiumVehicleType.cruise:
        return 'Cruise Ship';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case BoardingPassStatus.upcoming:
        return 'Upcoming';
      case BoardingPassStatus.boarding:
        return 'Boarding';
      case BoardingPassStatus.departed:
        return 'Departed';
      case BoardingPassStatus.completed:
        return 'Completed';
      case BoardingPassStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive {
    return status == BoardingPassStatus.upcoming || 
           status == BoardingPassStatus.boarding;
  }

  bool get isPast {
    return status == BoardingPassStatus.departed || 
           status == BoardingPassStatus.completed ||
           status == BoardingPassStatus.cancelled;
  }

  String get estimatedDuration {
    if (arrivalTime == null) return 'N/A';
    final duration = arrivalTime!.difference(departureTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

// Helper extension for vehicle type icons
extension PremiumVehicleTypeExtension on PremiumVehicleType {
  String get iconPath {
    switch (this) {
      case PremiumVehicleType.chopper:
        return 'assets/icons/helicopter.png';
      case PremiumVehicleType.privateJet:
        return 'assets/icons/private_jet.png';
      case PremiumVehicleType.cruise:
        return 'assets/icons/cruise.png';
    }
  }

  String get emoji {
    switch (this) {
      case PremiumVehicleType.chopper:
        return '🚁';
      case PremiumVehicleType.privateJet:
        return '✈️';
      case PremiumVehicleType.cruise:
        return '🛳️';
    }
  }
}