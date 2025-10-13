enum DeliveryStatus {
  pending,
  confirmed,
  pickedUp,
  inTransit,
  outForDelivery,
  delivered,
  cancelled,
  failed,
}

enum PackageType {
  document,
  electronics,
  clothing,
  food,
  fragile,
  hazardous,
  oversized,
  other,
}

enum DeliveryPriority {
  standard,
  express,
  overnight,
  sameDay,
}

enum DeliveryVehicleType {
  cargoPlane,
  cargoShip,
}

class PackageDetails {
  final String description;
  final PackageType type;
  final double weight; // in kg
  final double length; // in cm
  final double width; // in cm
  final double height; // in cm
  final double? declaredValue; // in currency
  final bool isFragile;
  final bool requiresRefrigeration;
  final String? specialInstructions;

  const PackageDetails({
    required this.description,
    required this.type,
    required this.weight,
    required this.length,
    required this.width,
    required this.height,
    this.declaredValue,
    this.isFragile = false,
    this.requiresRefrigeration = false,
    this.specialInstructions,
  });

  double get volume => (length * width * height) / 1000000; // cubic meters
  double get volumetricWeight => volume * 167; // kg (standard air freight calculation)
  double get chargeableWeight => weight > volumetricWeight ? weight : volumetricWeight;

  PackageDetails copyWith({
    String? description,
    PackageType? type,
    double? weight,
    double? length,
    double? width,
    double? height,
    double? declaredValue,
    bool? isFragile,
    bool? requiresRefrigeration,
    String? specialInstructions,
  }) {
    return PackageDetails(
      description: description ?? this.description,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      declaredValue: declaredValue ?? this.declaredValue,
      isFragile: isFragile ?? this.isFragile,
      requiresRefrigeration: requiresRefrigeration ?? this.requiresRefrigeration,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'type': type.name,
      'weight': weight,
      'length': length,
      'width': width,
      'height': height,
      'declared_value': declaredValue,
      'is_fragile': isFragile,
      'requires_refrigeration': requiresRefrigeration,
      'special_instructions': specialInstructions,
    };
  }

  factory PackageDetails.fromJson(Map<String, dynamic> json) {
    return PackageDetails(
      description: json['description'],
      type: PackageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PackageType.other,
      ),
      weight: json['weight'].toDouble(),
      length: json['length'].toDouble(),
      width: json['width'].toDouble(),
      height: json['height'].toDouble(),
      declaredValue: json['declared_value']?.toDouble(),
      isFragile: json['is_fragile'] ?? false,
      requiresRefrigeration: json['requires_refrigeration'] ?? false,
      specialInstructions: json['special_instructions'],
    );
  }
}

class ContactDetails {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String? company;

  const ContactDetails({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.company,
  });

  String get fullAddress => '$address, $city, $state $postalCode, $country';

  ContactDetails copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? company,
  }) {
    return ContactDetails(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      company: company ?? this.company,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'company': company,
    };
  }

  factory ContactDetails.fromJson(Map<String, dynamic> json) {
    return ContactDetails(
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      postalCode: json['postal_code'],
      country: json['country'],
      company: json['company'],
    );
  }
}

class DeliveryBooking {
  final String id;
  final String trackingNumber;
  final ContactDetails sender;
  final ContactDetails recipient;
  final PackageDetails package;
  final DeliveryVehicleType vehicleType;
  final DeliveryPriority priority;
  final DeliveryStatus status;
  final DateTime createdAt;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualPickupTime;
  final DateTime? actualDeliveryTime;
  final double totalCost;
  final String? notes;
  final List<DeliveryUpdate> updates;

  const DeliveryBooking({
    required this.id,
    required this.trackingNumber,
    required this.sender,
    required this.recipient,
    required this.package,
    required this.vehicleType,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.estimatedPickupTime,
    this.estimatedDeliveryTime,
    this.actualPickupTime,
    this.actualDeliveryTime,
    required this.totalCost,
    this.notes,
    this.updates = const [],
  });

  String get vehicleTypeDisplayName {
    switch (vehicleType) {
      case DeliveryVehicleType.cargoPlane:
        return 'Air Freight';
      case DeliveryVehicleType.cargoShip:
        return 'Sea Freight';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case DeliveryStatus.pending:
        return 'Pending Confirmation';
      case DeliveryStatus.confirmed:
        return 'Confirmed';
      case DeliveryStatus.pickedUp:
        return 'Picked Up';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
      case DeliveryStatus.failed:
        return 'Failed';
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case DeliveryPriority.standard:
        return 'Standard';
      case DeliveryPriority.express:
        return 'Express';
      case DeliveryPriority.overnight:
        return 'Overnight';
      case DeliveryPriority.sameDay:
        return 'Same Day';
    }
  }

  bool get isActive {
    return status != DeliveryStatus.delivered &&
           status != DeliveryStatus.cancelled &&
           status != DeliveryStatus.failed;
  }

  DeliveryBooking copyWith({
    String? id,
    String? trackingNumber,
    ContactDetails? sender,
    ContactDetails? recipient,
    PackageDetails? package,
    DeliveryVehicleType? vehicleType,
    DeliveryPriority? priority,
    DeliveryStatus? status,
    DateTime? createdAt,
    DateTime? estimatedPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? actualPickupTime,
    DateTime? actualDeliveryTime,
    double? totalCost,
    String? notes,
    List<DeliveryUpdate>? updates,
  }) {
    return DeliveryBooking(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      package: package ?? this.package,
      vehicleType: vehicleType ?? this.vehicleType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      totalCost: totalCost ?? this.totalCost,
      notes: notes ?? this.notes,
      updates: updates ?? this.updates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tracking_number': trackingNumber,
      'sender': sender.toJson(),
      'recipient': recipient.toJson(),
      'package': package.toJson(),
      'vehicle_type': vehicleType.name,
      'priority': priority.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'estimated_pickup_time': estimatedPickupTime?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'actual_pickup_time': actualPickupTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'total_cost': totalCost,
      'notes': notes,
      'updates': updates.map((u) => u.toJson()).toList(),
    };
  }

  factory DeliveryBooking.fromJson(Map<String, dynamic> json) {
    return DeliveryBooking(
      id: json['id'],
      trackingNumber: json['tracking_number'],
      sender: ContactDetails.fromJson(json['sender']),
      recipient: ContactDetails.fromJson(json['recipient']),
      package: PackageDetails.fromJson(json['package']),
      vehicleType: DeliveryVehicleType.values.firstWhere(
        (e) => e.name == json['vehicle_type'],
        orElse: () => DeliveryVehicleType.cargoPlane,
      ),
      priority: DeliveryPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => DeliveryPriority.standard,
      ),
      status: DeliveryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeliveryStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at']),
      estimatedPickupTime: json['estimated_pickup_time'] != null
          ? DateTime.parse(json['estimated_pickup_time'])
          : null,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'])
          : null,
      actualPickupTime: json['actual_pickup_time'] != null
          ? DateTime.parse(json['actual_pickup_time'])
          : null,
      actualDeliveryTime: json['actual_delivery_time'] != null
          ? DateTime.parse(json['actual_delivery_time'])
          : null,
      totalCost: json['total_cost'].toDouble(),
      notes: json['notes'],
      updates: (json['updates'] as List<dynamic>?)
          ?.map((u) => DeliveryUpdate.fromJson(u))
          .toList() ?? [],
    );
  }
}

class DeliveryUpdate {
  final String id;
  final String deliveryId;
  final DeliveryStatus status;
  final DateTime timestamp;
  final String message;
  final String? location;
  final String? notes;

  const DeliveryUpdate({
    required this.id,
    required this.deliveryId,
    required this.status,
    required this.timestamp,
    required this.message,
    this.location,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'location': location,
      'notes': notes,
    };
  }

  factory DeliveryUpdate.fromJson(Map<String, dynamic> json) {
    return DeliveryUpdate(
      id: json['id'],
      deliveryId: json['delivery_id'],
      status: DeliveryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeliveryStatus.pending,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
      location: json['location'],
      notes: json['notes'],
    );
  }
}

// Helper extensions
extension PackageTypeExtension on PackageType {
  String get displayName {
    switch (this) {
      case PackageType.document:
        return 'Documents';
      case PackageType.electronics:
        return 'Electronics';
      case PackageType.clothing:
        return 'Clothing';
      case PackageType.food:
        return 'Food & Beverages';
      case PackageType.fragile:
        return 'Fragile Items';
      case PackageType.hazardous:
        return 'Hazardous Materials';
      case PackageType.oversized:
        return 'Oversized Items';
      case PackageType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PackageType.document:
        return '📄';
      case PackageType.electronics:
        return '📱';
      case PackageType.clothing:
        return '👕';
      case PackageType.food:
        return '🍱';
      case PackageType.fragile:
        return '⚠️';
      case PackageType.hazardous:
        return '☢️';
      case PackageType.oversized:
        return '📦';
      case PackageType.other:
        return '📋';
    }
  }
}

extension DeliveryPriorityExtension on DeliveryPriority {
  String get description {
    switch (this) {
      case DeliveryPriority.standard:
        return '5-7 business days';
      case DeliveryPriority.express:
        return '2-3 business days';
      case DeliveryPriority.overnight:
        return 'Next business day';
      case DeliveryPriority.sameDay:
        return 'Same day delivery';
    }
  }

  double get multiplier {
    switch (this) {
      case DeliveryPriority.standard:
        return 1.0;
      case DeliveryPriority.express:
        return 1.5;
      case DeliveryPriority.overnight:
        return 2.0;
      case DeliveryPriority.sameDay:
        return 3.0;
    }
  }
}