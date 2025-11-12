# Ride Request Payload Flow

## Overview
This document describes the complete flow of data from passenger app → backend → driver app for ride requests.

## 1. Passenger App Sends (socket_service.dart)

The passenger app emits a `ride_request` event with the following payload:

```dart
{
  // Passenger info - REQUIRED
  'passenger_id': String,
  'passenger_name': String,
  'passenger_phone': String,
  'passenger_image': String?, // optional
  
  // Pickup location - REQUIRED
  'pickup_latitude': double,
  'pickup_longitude': double,
  'pickup_address': String,
  
  // Destination location - REQUIRED
  'destination_latitude': double,
  'destination_longitude': double,
  'destination_address': String,
  
  // Trip details - Backend will recalculate
  'distance': double?, // in km, optional
  'duration': int?, // in minutes, optional
  'fare': double?, // optional
  
  // Status and timestamp
  'status': 'requested',
  'requested_at': ISO8601 String,
  
  // Vehicle type for driver matching - IMPORTANT
  'vehicle_type': String?, // 'car', 'suv', 'bike', etc.
  
  // Optional notes
  'notes': String?,
}
```

## 2. Backend Processes (passengerHandler.ts)

The backend receives the payload and:

1. **Validates** using `RideRequestSchema` (types/index.ts lines 105-137)
2. **Generates** a new UUID `ride_id`
3. **Calculates** accurate distance and duration using Google Maps API
4. **Gets** route polyline and steps
5. **Calculates** fare based on distance and duration
6. **Creates** full `Ride` object with all fields
7. **Saves** to database
8. **Finds** nearby drivers matching the vehicle type
9. **Broadcasts** to drivers

## 3. Backend Sends to Drivers (passengerHandler.ts lines 333-337)

```typescript
{
  // Full Ride object fields:
  'ride_id': String (UUID),
  'passenger_id': String,
  'passenger_name': String,
  'passenger_phone': String,
  'passenger_image': String | null,
  'pickup_latitude': number,
  'pickup_longitude': number,
  'pickup_address': String,
  'destination_latitude': number,
  'destination_longitude': number,
  'destination_address': String,
  'distance': String, // e.g., "5.25" (km)
  'distance_text': String, // e.g., "5.3 km"
  'duration': number, // minutes (rounded)
  'duration_text': String, // e.g., "12 mins"
  'fare': String, // e.g., "150.00"
  'route_polyline': String | null,
  'route_steps': Array | null,
  'status': 'requested' | 'accepted' | 'started' | 'completed' | 'cancelled',
  'notes': String | null,
  'requested_at': ISO8601 String,
  'vehicle_type': String?, // Requested vehicle type
  'driver_id': null,
  'accepted_at': null,
  'started_at': null,
  'completed_at': null,
  'rating': null,
  'feedback': null,
  
  // Driver-specific fields added by backend:
  'estimated_arrival': String, // e.g., "10 minutes"
  'driver_distance': String, // e.g., "2.50" (km from driver to pickup)
  'timestamp': ISO8601 String,
}
```

## 4. Driver App Receives (ride_model.dart)

The driver app's `Ride.fromJson()` parses the payload:

```dart
class Ride {
  final String id; // from 'ride_id' or 'id'
  final String driverId; // from 'driver_id' (empty string if null)
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String? passengerImage;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationAddress;
  final double distance; // parsed from string to double
  final double fare; // parsed from string to double
  final double? duration; // parsed from string/number to double
  final RideStatus status;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final double? rating;
  final String? feedback;
  final String? routePolyline;
  final String? driverToPickupPolyline;
  final String? driverToPickupDistance;
  final String? driverToPickupDuration;
  final double? driverLatitude;
  final double? driverLongitude;
}
```

## Key Points

### Type Conversions
- Backend stores `distance`, `fare`, `duration` as **strings** in the Ride object
- Driver app uses `_toDouble()` helper to safely parse these strings to doubles
- Backend calculates accurate values even if passenger app provides estimates

### Vehicle Type Filtering
- Passenger app sends `vehicle_type` (e.g., 'car', 'suv', 'bike')
- Backend filters nearby drivers to match the requested vehicle type
- Synonyms handled: 'car'/'sedan', 'bike'/'motorcycle'/'motorbike'

### Driver Distance Calculation
- Backend calculates distance from each driver to pickup location
- Adds `driver_distance` and `estimated_arrival` to the payload sent to drivers
- Each driver gets personalized distance information

### Multiple Broadcast Methods
Backend uses triple delivery for maximum reliability:
1. Driver-specific room: `driver_{driver_id}`
2. Direct socket ID
3. Global `available_drivers` room

### Event Names
Backend emits both:
- `ride_request` (new format)
- `ride:request` (legacy format)

This ensures compatibility with different driver app versions.

## Payload Alignment Status

✅ **ALIGNED** - Passenger app sends correct payload matching `RideRequestSchema`
✅ **ALIGNED** - Backend processes and enriches the payload correctly
✅ **ALIGNED** - Driver app can parse the full `Ride` object from backend

## Testing Checklist

- [ ] Passenger app sends all required fields
- [ ] Backend receives and validates payload
- [ ] Backend calculates distance/duration/fare correctly
- [ ] Backend finds nearby drivers with vehicle type filter
- [ ] Backend broadcasts to drivers successfully
- [ ] Driver app receives and parses payload
- [ ] Driver app displays ride request correctly
- [ ] Driver can accept/reject ride
- [ ] Passenger receives acceptance notification
