# Live Tracking Implementation Guide

## Overview
This document describes the complete real-time tracking flow between driver and passenger apps.

## Passenger App Changes (✅ COMPLETED)

### 1. Enhanced Driver Location Tracking
**File**: `lib/screens/ride_details_screen.dart`

**Changes Made**:
- Added comprehensive debug logging for all driver location updates
- Improved socket listener to track driver movement with detailed logs
- Added smooth camera animation when driver location updates (500ms duration)
- Enhanced error handling for invalid location data

**How it works**:
```dart
// Socket listener receives driver location
_socketDriverLocSub = SocketService.instance.driverLocationStream.listen((data) {
  // Logs: 📍 Received driver location update
  // Logs: 🚗 Driver moved from X,Y to A,B
  
  setState(() {
    _driverLatLng = newPos;  // Updates marker position
  });
  
  // Smoothly animates camera to follow driver
  _mapController?.animateCamera(
    CameraUpdate.newLatLng(newPos),
    duration: const Duration(milliseconds: 500),
  );
});
```

**Current Map Features**:
- ✅ Shows driver marker (blue pin) that updates in real-time
- ✅ **Smooth animated marker movement** - driver marker glides smoothly between location updates (1 second animation with ease-out)
- ✅ Shows pickup marker (green pin)  
- ✅ Shows destination marker (red pin)
- ✅ Displays polyline route
- ✅ Camera follows driver movement smoothly
- ✅ Automatically switches route after ride starts (driver→destination)

### 2. Existing Features Already Working
- ✅ Driver details display (name, phone, car, rating, vehicle number)
- ✅ OTP display for passenger
- ✅ Ride status tracking (En route → Driver Arrived → On Trip)
- ✅ Auto-detects when driver arrives within 100m of pickup
- ✅ Real-time route recalculation as driver moves
- ✅ Call and message driver buttons

---

## Driver App Implementation (📋 TODO)

### Required Features

#### 1. Real-Time Location Broadcasting
**Where**: Driver's active ride screen

**Requirements**:
```dart
import 'package:geolocator/geolocator.dart';
import '../services/socket_service.dart';

// Start location tracking when ride is accepted
Timer? _locationTimer;

void startLocationTracking(String rideId) {
  // Send location every 5-10 seconds
  _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    // Emit to backend via socket
    SocketService.instance.emit('driver_location_update', {
      'ride_id': rideId,
      'driver_id': driverId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'heading': position.heading,
      'speed': position.speed,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Also update Supabase drivers table
    await Supabase.instance.client
        .from('drivers')
        .update({
          'current_latitude': position.latitude,
          'current_longitude': position.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', driverId);
  });
}

void stopLocationTracking() {
  _locationTimer?.cancel();
}
```

**Permissions Required** (AndroidManifest.xml / Info.plist):
```xml
<!-- Android -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- iOS (Info.plist) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show your position to passengers</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to update passengers even when app is in background</string>
```

#### 2. OTP Verification Screen
**When**: Driver reaches pickup location

**UI Flow**:
```
Driver arrives → "Driver Arrived" button appears → 
Driver clicks → OTP input dialog shows → 
Driver enters passenger's OTP → 
Verify via backend → 
On success: Ride starts, navigate to active ride screen
```

**Implementation**:
```dart
// Show OTP dialog when driver clicks "I've Arrived"
void _showOTPDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Verify Passenger OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ask the passenger for their trip OTP'),
          SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              labelText: 'Enter OTP',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _verifyOTPAndStartRide,
          child: Text('Start Ride'),
        ),
      ],
    ),
  );
}

Future<void> _verifyOTPAndStartRide() async {
  final enteredOTP = _otpController.text.trim();
  
  try {
    // Verify OTP via backend/Supabase
    final response = await Supabase.instance.client
        .from('rides')
        .select('trip_otp')
        .eq('id', rideId)
        .single();
    
    if (response['trip_otp'] == enteredOTP) {
      // OTP correct - start ride
      await Supabase.instance.client
          .from('rides')
          .update({
            'status': 'started',
            'started_at': DateTime.now().toIso8601String(),
            'otp_verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);
      
      // Emit socket event
      SocketService.instance.emit('ride_started', {
        'ride_id': rideId,
        'driver_id': driverId,
        'started_at': DateTime.now().toIso8601String(),
      });
      
      // Create ride event
      await Supabase.instance.client
          .from('ride_events')
          .insert({
            'ride_id': rideId,
            'actor': 'driver',
            'event_type': 'ride:started',
            'payload': {
              'otp_verified': true,
              'verification_time': DateTime.now().toIso8601String(),
            },
          });
      
      Navigator.pop(context); // Close dialog
      
      // Navigate to active ride screen (destination tracking)
      Navigator.pushReplacementNamed(
        context,
        '/driver/active-ride',
        arguments: {'rideId': rideId},
      );
    } else {
      // OTP incorrect
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incorrect OTP. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('Error verifying OTP: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

#### 3. Active Ride Screen (After OTP Verification)
**Shows**:
- Map with current location → destination route
- Live passenger location (if sharing)
- ETA and distance to destination
- "Complete Ride" button

**Map Implementation**:
```dart
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: driverCurrentLocation,
    zoom: 15,
  ),
  myLocationEnabled: true,
  myLocationButtonEnabled: true,
  markers: {
    // Destination marker
    Marker(
      markerId: MarkerId('destination'),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'Destination'),
    ),
    // Optional: Passenger location marker
    if (passengerLatLng != null)
      Marker(
        markerId: MarkerId('passenger'),
        position: passengerLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Passenger'),
      ),
  },
  polylines: {
    Polyline(
      polylineId: PolylineId('route'),
      points: routeToDestination,
      color: Colors.blue,
      width: 5,
    ),
  },
)
```

---

## Backend Requirements (Socket.IO Events)

### Events Driver App Must Emit

1. **`driver_location_update`** (every 5-10 seconds during ride)
   ```json
   {
     "ride_id": "uuid",
     "driver_id": "uuid",
     "latitude": 22.278654,
     "longitude": 73.237336,
     "heading": 180.0,
     "speed": 35.5,
     "timestamp": "2025-10-30T10:46:53Z"
   }
   ```

2. **`ride_started`** (after OTP verification)
   ```json
   {
     "ride_id": "uuid",
     "driver_id": "uuid",
     "driver_name": "John Doe",
     "started_at": "2025-10-30T10:46:53Z",
     "otp_verified": true
   }
   ```

3. **`ride_completed`** (when reaching destination)
   ```json
   {
     "ride_id": "uuid",
     "driver_id": "uuid",
     "completed_at": "2025-10-30T11:15:00Z",
     "final_fare": 150.00,
     "distance": "12.5 km",
     "duration": "28 mins"
   }
   ```

### Events Backend Must Broadcast

1. **`driver_location_update`** → to passenger room
2. **`ride_started`** → to passenger
3. **`ride_completed`** → to both passenger and driver

---

## Complete Flow Diagram

```
PASSENGER APP                    DRIVER APP                      BACKEND
============================================================================

1. Passenger requests ride
   [Searching Screen]
                           →     [Shows ride request]
                           ←     Driver accepts
   [Navigate to Ride Details]
   
2. Real-time tracking begins
   [Map shows driver moving] ←── [Broadcasts location]     ←── Socket events
                                 [Every 5-10 seconds]
   
3. Driver arrives at pickup
   [Status: "Driver Arrived"] ←  [Clicks "I've Arrived"]   
   [Shows OTP: 1234]         →  [Shows OTP dialog]
                             →  [Driver enters: 1234]
                             →  [Verifies with backend]  →  Checks OTP
                             ←  [Success response]        ←  OTP valid
   
4. Ride starts
   [Status: "On Trip"]       ←  [Emits ride_started]     ←  Broadcast
   [Map: pickup→destination]    [Navigate to Active Ride]
   [Route updates in real-time] [Shows route to destination]
   
5. Driver reaches destination
   [Navigates to Payment]    ←  [Completes ride]         ←  ride_completed
```

---

## Testing Checklist

### Driver App
- [ ] Location permissions requested and granted
- [ ] Location updates every 5-10 seconds during ride
- [ ] OTP dialog appears when driver clicks "I've Arrived"
- [ ] OTP verification works correctly
- [ ] Ride status updates to "started" after OTP
- [ ] Active ride screen shows correct route
- [ ] Location tracking continues until ride completion
- [ ] Complete ride button works

### Passenger App
- [ ] Driver location updates on map in real-time
- [ ] Map camera follows driver smoothly
- [ ] Driver name/details display correctly
- [ ] OTP displays correctly
- [ ] Status changes: "En route" → "Driver Arrived" → "On Trip"
- [ ] Route updates when ride starts
- [ ] Can call/message driver
- [ ] Navigates to payment after ride completion

### Backend
- [ ] Socket events broadcast correctly
- [ ] driver_location_update reaches passenger
- [ ] ride_started event triggers status change
- [ ] OTP stored correctly in database
- [ ] Ride status updates persist

---

## Troubleshooting

### Driver location not updating on passenger map

**Check**:
1. Driver app is sending location updates (check logs)
2. Socket.IO connection is active on both apps
3. Passenger is subscribed to correct ride room
4. Backend is broadcasting `driver_location_update` events

**Debug logs to add**:
```dart
// Driver app
print('📍 Sending location: $latitude, $longitude');

// Passenger app  
print('📍 Received driver location: $data');
print('🚗 Driver moved to: $lat, $lng');
```

### OTP verification failing

**Check**:
1. OTP is generated correctly when ride is accepted
2. OTP is stored in `rides.trip_otp` field
3. Driver enters exact OTP (no spaces)
4. OTP hasn't expired if time-based

### Map not showing driver

**Check**:
1. `_driverLatLng` state variable is updating
2. Map markers are rebuilt when state changes
3. Camera position is animating to driver location
4. Driver's initial location was received on ride acceptance

---

## Next Steps

1. **Implement driver app changes** following the code examples above
2. **Test location broadcasting** in driver app
3. **Test OTP flow** with real driver-passenger scenario  
4. **Verify map updates** in both apps simultaneously
5. **Add custom car icon markers** (optional enhancement)
6. **Implement offline handling** (optional - queue location updates)

---

## Additional Enhancements (Optional)

### 1. Custom Car Icon Markers
Replace default blue marker with a car icon that rotates based on driver's heading.

### 2. ~~Smooth Marker Animation~~ (✅ Already Implemented!)
~~Instead of jumping, animate marker movement between location updates.~~

**Status**: The driver marker now smoothly animates between location updates using a 30-frame ease-out animation over 1 second. When a new location update arrives, the marker glides smoothly from the old position to the new one instead of jumping.

### 3. ETA Calculation
Show real-time ETA based on driver's current location and speed.

### 4. Route Deviation Alerts
Alert passenger if driver significantly deviates from route.

### 5. Passenger Location Sharing
Allow passenger to share their live location with driver during trip.

---

## Contact & Support
For questions or issues implementing this flow, refer to the codebase or contact the development team.
