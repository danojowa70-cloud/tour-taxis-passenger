enum ReceiptType {
  instantRide,
  scheduledRide,
  premiumBooking,
  cargoDelivery,
}

class Receipt {
  final String id;
  final ReceiptType type;
  final String bookingId;
  final String passengerName;
  final DateTime dateTime;
  final double totalAmount;
  final String status;
  final String? driverName;
  final String? vehicleInfo;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? distance;
  final double? duration;
  final String? paymentMethod;
  final Map<String, dynamic>? additionalDetails;

  const Receipt({
    required this.id,
    required this.type,
    required this.bookingId,
    required this.passengerName,
    required this.dateTime,
    required this.totalAmount,
    required this.status,
    this.driverName,
    this.vehicleInfo,
    this.pickupAddress,
    this.destinationAddress,
    this.distance,
    this.duration,
    this.paymentMethod,
    this.additionalDetails,
  });

  String get typeDisplayName {
    switch (type) {
      case ReceiptType.instantRide:
        return 'Instant Ride';
      case ReceiptType.scheduledRide:
        return 'Scheduled Ride';
      case ReceiptType.premiumBooking:
        return 'Premium Booking';
      case ReceiptType.cargoDelivery:
        return 'Cargo Delivery';
    }
  }

  String get typeIcon {
    switch (type) {
      case ReceiptType.instantRide:
        return '🚗';
      case ReceiptType.scheduledRide:
        return '📅';
      case ReceiptType.premiumBooking:
        return '✈️';
      case ReceiptType.cargoDelivery:
        return '📦';
    }
  }

  factory Receipt.fromInstantRide(Map<String, dynamic> json) {
    return Receipt(
      id: json['id']?.toString() ?? '',
      type: ReceiptType.instantRide,
      bookingId: json['id']?.toString() ?? 'N/A',
      passengerName: json['passenger_name']?.toString() ?? 
                     json['user_name']?.toString() ?? 
                     'Unknown',
      dateTime: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      totalAmount: (json['fare'] ?? json['total_amount'] ?? 0) is num
          ? (json['fare'] ?? json['total_amount'] ?? 0).toDouble()
          : 0.0,
      status: json['status']?.toString() ?? 'completed',
      driverName: json['driver_name']?.toString(),
      vehicleInfo: json['vehicle_type']?.toString() ?? json['vehicle_model']?.toString(),
      pickupAddress: json['pickup_address']?.toString() ?? json['pickup_location']?.toString(),
      destinationAddress: json['destination_address']?.toString() ?? json['destination_location']?.toString(),
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      paymentMethod: json['payment_method']?.toString() ?? 'Cash',
    );
  }

  factory Receipt.fromScheduledRide(Map<String, dynamic> json) {
    return Receipt(
      id: json['id']?.toString() ?? '',
      type: ReceiptType.scheduledRide,
      bookingId: json['id']?.toString() ?? 'N/A',
      passengerName: json['passenger_name']?.toString() ?? 
                     json['user_name']?.toString() ?? 
                     'Unknown',
      dateTime: json['scheduled_time'] != null 
          ? DateTime.parse(json['scheduled_time'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      totalAmount: (json['fare'] ?? json['estimated_fare'] ?? json['total_amount'] ?? 0) is num
          ? (json['fare'] ?? json['estimated_fare'] ?? json['total_amount'] ?? 0).toDouble()
          : 0.0,
      status: json['status']?.toString() ?? 'pending',
      driverName: json['driver_name']?.toString(),
      vehicleInfo: json['vehicle_type']?.toString() ?? json['vehicle_model']?.toString(),
      pickupAddress: json['pickup_location']?.toString() ?? json['pickup_address']?.toString(),
      destinationAddress: json['destination_location']?.toString() ?? json['destination_address']?.toString(),
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      paymentMethod: json['payment_method']?.toString() ?? 'Cash',
    );
  }

  factory Receipt.fromPremiumBooking(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'],
      type: ReceiptType.premiumBooking,
      bookingId: json['booking_id'] ?? json['id'],
      passengerName: json['passenger_name'] ?? 'Unknown',
      dateTime: DateTime.parse(json['departure_time']),
      totalAmount: (json['fare'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'completed',
      vehicleInfo: json['vehicle_type'],
      pickupAddress: json['origin'],
      destinationAddress: json['destination'],
      paymentMethod: 'Premium Booking',
      additionalDetails: {
        'operator_name': json['operator_name'],
        'seat_number': json['seat_number'],
        'gate': json['gate'],
      },
    );
  }

  factory Receipt.fromCargoDelivery(Map<String, dynamic> json) {
    // Handle pickup address
    String? pickupAddr;
    final senderAddress = json['sender_address'] ?? json['pickup_address'];
    final senderCity = json['sender_city'] ?? json['pickup_city'];
    final senderState = json['sender_state'] ?? json['pickup_state'];
    
    if (senderAddress != null && senderAddress.toString().isNotEmpty) {
      final parts = [senderAddress];
      if (senderCity != null && senderCity.toString().isNotEmpty) parts.add(senderCity);
      if (senderState != null && senderState.toString().isNotEmpty) parts.add(senderState);
      pickupAddr = parts.join(', ');
    }
    
    // Handle destination address
    String? destAddr;
    final recipientAddress = json['recipient_address'] ?? json['delivery_address'];
    final recipientCity = json['recipient_city'] ?? json['delivery_city'];
    final recipientState = json['recipient_state'] ?? json['delivery_state'];
    
    if (recipientAddress != null && recipientAddress.toString().isNotEmpty) {
      final parts = [recipientAddress];
      if (recipientCity != null && recipientCity.toString().isNotEmpty) parts.add(recipientCity);
      if (recipientState != null && recipientState.toString().isNotEmpty) parts.add(recipientState);
      destAddr = parts.join(', ');
    }
    
    return Receipt(
      id: json['id']?.toString() ?? '',
      type: ReceiptType.cargoDelivery,
      bookingId: json['tracking_number']?.toString() ?? json['id']?.toString() ?? 'N/A',
      passengerName: json['sender_name']?.toString() ?? json['user_name']?.toString() ?? 'Unknown',
      dateTime: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      totalAmount: (json['total_cost'] ?? json['price'] ?? json['fare'] ?? 0) is num 
          ? (json['total_cost'] ?? json['price'] ?? json['fare'] ?? 0).toDouble() 
          : 0.0,
      status: json['status']?.toString() ?? 'pending',
      driverName: json['driver_name']?.toString(), // May be available for some cargo deliveries
      vehicleInfo: json['vehicle_type']?.toString(),
      pickupAddress: pickupAddr,
      destinationAddress: destAddr,
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      paymentMethod: json['payment_status'] == 'completed' || json['payment_status'] == 'paid'
          ? 'Paid' 
          : json['payment_method']?.toString() ?? 'Pending',
      additionalDetails: {
        if (json['package_description'] != null) 
          'package_description': json['package_description'],
        if (json['package_type'] != null) 
          'package_type': json['package_type'],
        if (json['package_weight'] != null) 
          'weight': json['package_weight'],
        if (json['weight'] != null) 
          'weight': json['weight'],
        if (json['priority'] != null) 
          'priority': json['priority'],
        if (json['recipient_name'] != null) 
          'recipient_name': json['recipient_name'],
        if (json['recipient_phone'] != null) 
          'recipient_phone': json['recipient_phone'],
      },
    );
  }
}
