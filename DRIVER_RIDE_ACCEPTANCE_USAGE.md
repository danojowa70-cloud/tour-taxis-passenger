# Driver Ride Acceptance Implementation

This document explains how to use the driver ride acceptance feature that sends driver data to the passenger app.

## Overview

When a driver clicks the "Accept" button on a ride request, the following happens:

1. The ride status is updated to 'accepted' in the database
2. Driver information is linked to the ride
3. A `ride:accepted` event is created with complete driver data
4. The passenger app receives the driver data in real-time via Supabase subscriptions
5. The driver's availability is set to unavailable

## Components Created

### 1. Service Method: `acceptRide` (ride_service.dart)

```dart
final rideService = RideService(Supabase.instance.client);

final success = await rideService.acceptRide(
  rideId: 'ride-uuid',
  driverId: 'driver-uuid',
);
```

### 2. Backend API Endpoint

**POST** `/api/rides/:rideId/accept`

```json
{
  "driverId": "driver-uuid"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Ride accepted successfully",
  "ride": { /* ride data */ },
  "driver": { /* driver data */ }
}
```

### 3. UI Widget: `DriverRideRequestCard`

A ready-to-use widget that displays ride request details with an accept button.

## Usage Example

### In a Driver Home Screen or Notification Handler:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/driver_ride_request_card.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  List<Map<String, dynamic>> _pendingRides = [];
  RealtimeChannel? _rideChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToRideRequests();
  }

  void _subscribeToRideRequests() {
    // Listen for new ride events
    _rideChannel = Supabase.instance.client
        .channel('driver_ride_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_events',
          callback: (payload) async {
            final event = payload.newRecord;
            if (event['event_type'] == 'ride:notify_driver') {
              final rideData = event['payload']['ride_data'];
              
              // Add to pending rides if still requested
              if (rideData['status'] == 'requested') {
                setState(() {
                  _pendingRides.add(rideData);
                });
              }
            }
          },
        )
        .subscribe();

    // Also fetch any existing requested rides nearby
    _fetchNearbyRequestedRides();
  }

  Future<void> _fetchNearbyRequestedRides() async {
    // Implement fetching logic based on driver's location
    // This is just a placeholder example
    final rides = await Supabase.instance.client
        .from('rides')
        .select()
        .eq('status', 'requested')
        .limit(10);

    setState(() {
      _pendingRides = List<Map<String, dynamic>>.from(rides);
    });
  }

  @override
  void dispose() {
    _rideChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
      ),
      body: _pendingRides.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_taxi, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No ride requests at the moment',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _pendingRides.length,
              itemBuilder: (context, index) {
                final ride = _pendingRides[index];
                return DriverRideRequestCard(
                  rideRequest: ride,
                  onAccepted: () {
                    // Remove from list and navigate to ride screen
                    setState(() {
                      _pendingRides.removeAt(index);
                    });
                    
                    // Navigate to active ride screen
                    Navigator.pushNamed(
                      context,
                      '/driver/active-ride',
                      arguments: ride['id'],
                    );
                  },
                  onDismissed: () {
                    // Remove from list
                    setState(() {
                      _pendingRides.removeAt(index);
                    });
                  },
                );
              },
            ),
    );
  }
}
```

## What the Passenger App Receives

When the driver accepts a ride, the passenger app will receive a real-time update via the `ride:accepted` event:

```dart
// In the passenger app's ride tracking screen
Supabase.instance.client
    .channel('ride_updates')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'ride_events',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'ride_id',
        value: rideId,
      ),
      callback: (payload) {
        final event = payload.newRecord;
        if (event['event_type'] == 'ride:accepted') {
          final driverData = event['payload']['driver_data'];
          
          // Update UI with driver information
          setState(() {
            driverName = driverData['name'];
            driverPhone = driverData['phone'];
            vehicleInfo = '${driverData['vehicle_make']} ${driverData['vehicle_model']}';
            vehiclePlate = driverData['vehicle_plate'];
            driverRating = driverData['rating'];
          });
        }
      },
    )
    .subscribe();
```

## Driver Data Structure Sent to Passenger

```json
{
  "driver_id": "uuid",
  "driver_name": "John Doe",
  "driver_phone": "+1234567890",
  "driver_car": "Toyota Camry",
  "vehicle_type": "sedan",
  "vehicle_number": "ABC123",
  "vehicle_plate": "XYZ-1234",
  "driver_rating": 4.8,
  "driver_data": {
    "id": "uuid",
    "name": "John Doe",
    "phone": "+1234567890",
    "vehicle_make": "Toyota",
    "vehicle_model": "Camry",
    "vehicle_type": "sedan",
    "vehicle_number": "ABC123",
    "vehicle_plate": "XYZ-1234",
    "rating": 4.8
  }
}
```

## Database Tables Involved

### 1. `rides` table
- Updated with `driver_id`, `status='accepted'`, and `accepted_at` timestamp

### 2. `drivers` table
- Driver's `is_available` flag is set to `false`

### 3. `ride_events` table
- New event inserted with type `ride:accepted` containing all driver data

## Testing

1. **As a Driver:**
   - Log in to the driver app
   - Go online and make yourself available
   - Wait for or manually create a ride request
   - See the ride request card appear
   - Click "Accept Ride"
   - Verify success message appears
   - Confirm you're navigated to the active ride screen

2. **As a Passenger:**
   - Create a ride request
   - Wait for a driver to accept
   - Verify driver information appears in real-time
   - Check that driver name, phone, vehicle details, and rating are displayed

## Next Steps

To fully integrate this feature:

1. Add the `DriverRideRequestCard` widget to your driver home screen
2. Set up real-time subscriptions to listen for new ride requests
3. Handle navigation after ride acceptance
4. Implement the active ride tracking screen for drivers
5. Test the complete flow from request to acceptance

## Troubleshooting

**Driver data not appearing on passenger app:**
- Check Supabase real-time is enabled on your project
- Verify the `ride_events` table has proper RLS policies
- Check browser/app console for subscription errors

**Accept button not working:**
- Ensure driver is authenticated
- Verify driver has a record in the `drivers` table linked to their auth user
- Check driver's `is_online` and `is_available` flags are true
