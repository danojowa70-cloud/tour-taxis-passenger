enum VehicleType {
  bike,
  sedan,
  suv,
  // Premium vehicles
  chopper,
  privateJet,
  cruise,
  // Delivery vehicles
  cargoPlane,
  cargoShip,
}

class VehicleTypeInfo {
  final VehicleType type;
  final String id;
  final String name;
  final String icon;
  final String description;
  final double pricePerKm; // KSh per kilometer
  final int capacity;
  final String estimatedArrivalTime;

  const VehicleTypeInfo({
    required this.type,
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.pricePerKm,
    required this.capacity,
    required this.estimatedArrivalTime,
  });

  // Kenya pricing structure as specified
  static const Map<VehicleType, VehicleTypeInfo> _vehicleInfo = {
    VehicleType.bike: VehicleTypeInfo(
      type: VehicleType.bike,
      id: 'bike',
      name: 'TourTaxi Bike',
      icon: '🏍️',
      description: '1 seat • Fast & Economical',
      pricePerKm: 25.0, // 25 KSh per km
      capacity: 1,
      estimatedArrivalTime: '2 min',
    ),
    VehicleType.sedan: VehicleTypeInfo(
      type: VehicleType.sedan,
      id: 'car', // Keep existing ID for compatibility
      name: 'TourTaxi Car',
      icon: '🚗',
      description: '4 seats • Comfortable',
      pricePerKm: 40.0, // 40 KSh per km
      capacity: 4,
      estimatedArrivalTime: '3 min',
    ),
    VehicleType.suv: VehicleTypeInfo(
      type: VehicleType.suv,
      id: 'suv',
      name: 'TourTaxi SUV',
      icon: '🚙',
      description: '6 seats • Premium & Spacious',
      pricePerKm: 50.0, // 50 KSh per km
      capacity: 6,
      estimatedArrivalTime: '5 min',
    ),
    // Premium vehicles with fixed pricing
    VehicleType.chopper: VehicleTypeInfo(
      type: VehicleType.chopper,
      id: 'chopper',
      name: 'Helicopter',
      icon: '🚁',
      description: '6 seats • Premium Air Travel',
      pricePerKm: 5000.0, // Fixed high price for premium service
      capacity: 6,
      estimatedArrivalTime: '15 min',
    ),
    VehicleType.privateJet: VehicleTypeInfo(
      type: VehicleType.privateJet,
      id: 'private_jet',
      name: 'Private Jet',
      icon: '✈️',
      description: '12 seats • Luxury Air Travel',
      pricePerKm: 15000.0, // Fixed high price for premium service
      capacity: 12,
      estimatedArrivalTime: '30 min',
    ),
    VehicleType.cargoPlane: VehicleTypeInfo(
      type: VehicleType.cargoPlane,
      id: 'cargo_plane',
      name: 'Cargo Plane',
      icon: '🛩️',
      description: 'Cargo transport • Freight service',
      pricePerKm: 8000.0, // Fixed price for cargo service
      capacity: 2, // Crew capacity
      estimatedArrivalTime: '45 min',
    ),
    VehicleType.cruise: VehicleTypeInfo(
      type: VehicleType.cruise,
      id: 'cruise',
      name: 'Cruise Ship',
      icon: '🛳️',
      description: '500+ capacity • Luxury Sea Travel',
      pricePerKm: 2000.0, // Per nautical mile pricing
      capacity: 500,
      estimatedArrivalTime: '2 hours',
    ),
    // Delivery vehicles with specialized pricing
    VehicleType.cargoShip: VehicleTypeInfo(
      type: VehicleType.cargoShip,
      id: 'cargo_ship',
      name: 'Cargo Ship',
      icon: '🚢',
      description: 'Sea Freight • Bulk Delivery',
      pricePerKm: 50.0, // Per container per nautical mile
      capacity: 1000, // Container capacity for display
      estimatedArrivalTime: '3-14 days',
    ),
  };

  static VehicleTypeInfo getInfo(VehicleType type) {
    return _vehicleInfo[type]!;
  }

  static VehicleTypeInfo getInfoById(String id) {
    return _vehicleInfo.values.firstWhere(
      (info) => info.id == id,
      orElse: () => _vehicleInfo[VehicleType.sedan]!, // Default to sedan
    );
  }

  static List<VehicleTypeInfo> getAllTypes() {
    return _vehicleInfo.values.toList();
  }

  static VehicleType? getTypeById(String id) {
    try {
      return _vehicleInfo.values.firstWhere((info) => info.id == id).type;
    } catch (e) {
      return null;
    }
  }

  // Helper methods for premium vehicles
  static bool isPremiumVehicle(VehicleType type) {
    return type == VehicleType.chopper ||
           type == VehicleType.privateJet ||
           type == VehicleType.cruise;
  }

  static List<VehicleTypeInfo> getStandardTypes() {
    // Standard ride types exclude both premium and delivery vehicles
    return _vehicleInfo.values
        .where((info) => !isPremiumVehicle(info.type) && !isDeliveryVehicle(info.type))
        .toList();
  }

  static List<VehicleTypeInfo> getPremiumTypes() {
    return _vehicleInfo.values
        .where((info) => isPremiumVehicle(info.type))
        .toList();
  }

  // Helper methods for delivery vehicles
  static bool isDeliveryVehicle(VehicleType type) {
    return type == VehicleType.cargoPlane ||
           type == VehicleType.cargoShip;
  }

  static List<VehicleTypeInfo> getDeliveryTypes() {
    return _vehicleInfo.values
        .where((info) => isDeliveryVehicle(info.type))
        .toList();
  }

  bool get isPremium => isPremiumVehicle(type);
  bool get isDelivery => isDeliveryVehicle(type);
}
