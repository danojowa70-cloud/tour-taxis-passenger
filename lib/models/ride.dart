class Ride {
  final String id;
  final String pickupLocation;
  final String dropoffLocation;
  final String driverName;
  final String driverCar;
  final double fare;
  final String status; // completed, cancelled, ongoing, scheduled
  final DateTime dateTime;
  final bool isScheduled;
  final DateTime? scheduledDateTime; // For scheduled rides

  const Ride({
    required this.id, 
    required this.pickupLocation, 
    required this.dropoffLocation, 
    required this.driverName, 
    required this.driverCar, 
    required this.fare, 
    required this.status, 
    required this.dateTime,
    this.isScheduled = false,
    this.scheduledDateTime,
  });

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
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      driverName: driverName,
      driverCar: driverCar,
      fare: fare,
      status: 'scheduled',
      dateTime: DateTime.now(),
      isScheduled: true,
      scheduledDateTime: scheduledDateTime,
    );
  }
}


