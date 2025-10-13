import '../models/vehicle_type.dart';

class FareService {
  // Kenya pricing structure - per kilometer charges
  // Bike: 25 KSh/km, Sedan: 40 KSh/km, SUV: 50 KSh/km
  
  final double baseFare;
  final double perMinute;

  const FareService({this.baseFare = 50.0, this.perMinute = 2.0});

  /// Calculate fare based on distance and vehicle type
  double estimateByVehicleType({
    required double distanceMeters,
    required double durationSeconds,
    required VehicleType vehicleType,
  }) {
    final km = distanceMeters / 1000.0;
    final minutes = durationSeconds / 60.0;
    
    final vehicleInfo = VehicleTypeInfo.getInfo(vehicleType);
    final distanceFare = km * vehicleInfo.pricePerKm;
    final timeFare = minutes * perMinute;
    
    final totalFare = baseFare + distanceFare + timeFare;
    
    // Round to nearest 5 KSh (common practice in Kenya)
    return (totalFare / 5).round() * 5.0;
  }

  /// Calculate fare by vehicle ID (for backward compatibility)
  double estimateByVehicleId({
    required double distanceMeters,
    required double durationSeconds,
    required String vehicleId,
  }) {
    final vehicleType = VehicleTypeInfo.getTypeById(vehicleId);
    if (vehicleType == null) {
      // Fallback to old calculation method
      return estimate(distanceMeters: distanceMeters, durationSeconds: durationSeconds);
    }
    
    return estimateByVehicleType(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      vehicleType: vehicleType,
    );
  }

  /// Get fare breakdown for a specific vehicle type
  FareBreakdown getFareBreakdown({
    required double distanceMeters,
    required double durationSeconds,
    required VehicleType vehicleType,
  }) {
    final km = distanceMeters / 1000.0;
    final minutes = durationSeconds / 60.0;
    
    final vehicleInfo = VehicleTypeInfo.getInfo(vehicleType);
    final distanceFare = km * vehicleInfo.pricePerKm;
    final timeFare = minutes * perMinute;
    
    final subtotal = baseFare + distanceFare + timeFare;
    final total = (subtotal / 5).round() * 5.0; // Round to nearest 5 KSh
    
    return FareBreakdown(
      baseFare: baseFare,
      distanceFare: distanceFare,
      timeFare: timeFare,
      subtotal: subtotal,
      total: total,
      distance: km,
      duration: minutes,
      vehicleType: vehicleType,
    );
  }

  /// Legacy method for backward compatibility
  double estimate({required double distanceMeters, required double durationSeconds}) {
    // Default to sedan pricing for backward compatibility
    return estimateByVehicleType(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      vehicleType: VehicleType.sedan,
    );
  }
}

/// Detailed fare breakdown for transparency
class FareBreakdown {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double subtotal;
  final double total;
  final double distance; // in km
  final double duration; // in minutes
  final VehicleType vehicleType;

  const FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.subtotal,
    required this.total,
    required this.distance,
    required this.duration,
    required this.vehicleType,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseFare': baseFare,
      'distanceFare': distanceFare,
      'timeFare': timeFare,
      'subtotal': subtotal,
      'total': total,
      'distance': distance,
      'duration': duration,
      'vehicleType': vehicleType.name,
    };
  }
}




