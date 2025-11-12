# 🚗 Driver App - Ride Request Integration Guide

## 📋 Overview

This document explains how the **Passenger App emits ride requests**, how the **Backend processes them**, and what data your **Driver App will receive**.

---

## 🔄 Complete Flow: Passenger → Backend → Driver

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Passenger App  │────1───►│  Backend Server  │────2───►│   Driver App    │
│                 │         │  (Socket.IO +    │         │                 │
│  Emits:         │         │   Supabase)      │         │  Receives:      │
│  'ride_request' │         │                  │         │  'ride_request' │
└─────────────────┘         └──────────────────┘         └─────────────────┘
                                     │
                                     │ 3. Saves to DB
                                     ▼
                            ┌─────────────────┐
                            │  Supabase DB    │
                            │  'rides' table  │
                            └─────────────────┘
```

---

## 📤 STEP 1: What Passenger App Sends

**Event Name**: `ride_request`

**Socket Emit Code** (Passenger App):
```dart
socket.emit('ride_request', {
  'passenger_id': 'uuid-1234-5678-90ab',
  'passenger_name': 'Jane Smith',
  'passenger_phone': '+254798765432',
  'passenger_image': 'https://example.com/photo.jpg',  // Optional
  
  'pickup_latitude': -1.286389,
  'pickup_longitude': 36.817223,
  'pickup_address': 'Nairobi CBD, Kenya',
  
  'destination_latitude': -1.319167,
  'destination_longitude': 36.925278,
  'destination_address': 'JKIA Airport, Nairobi',
  
  'notes': 'Please arrive in 5 minutes',  // Optional
  'fare': '850.00',                       // Optional (backend calculates if missing)
  'ride_id': 'ride-uuid-optional'         // Optional (backend generates if missing)
});
```

---

## ⚙️ STEP 2: What Backend Does Automatically

The backend (`tourtaxi-unified-backend`) receives the request and:

### **A. Validates & Enriches Data**
1. ✅ Validates all required fields
2. 🗺️ Calculates accurate distance using Google Maps/OSRM API
3. ⏱️ Calculates accurate duration (in seconds and text format)
4. 💰 Calculates fare if not provided
5. 🔑 Generates unique `ride_id` if not provided
6. 🛣️ Gets route polyline for map display
7. 📍 Gets turn-by-turn directions

### **B. Saves to Supabase Database**

**Table Name**: `rides`

**Columns Saved**:

| Column Name | Example Value | Description |
|------------|---------------|-------------|
| `id` | `"ride-abc-123"` | Unique ride identifier |
| `passenger_id` | `"uuid-1234"` | Passenger UUID |
| `passenger_name` | `"Jane Smith"` | Passenger's name |
| `passenger_phone` | `"+254798765432"` | Passenger's phone |
| `passenger_image` | `"https://..."` | Passenger photo URL (nullable) |
| `pickup_latitude` | `-1.286389` | Pickup GPS lat |
| `pickup_longitude` | `36.817223` | Pickup GPS lng |
| `pickup_address` | `"Nairobi CBD"` | Pickup address text |
| `destination_latitude` | `-1.319167` | Destination GPS lat |
| `destination_longitude` | `36.925278` | Destination GPS lng |
| `destination_address` | `"JKIA Airport"` | Destination address |
| `distance` | `15.43` | Distance in km (float) |
| `distance_text` | `"15.4 km"` | Human-readable distance |
| `duration` | `1200` | Duration in seconds (int) |
| `duration_text` | `"20 min"` | Human-readable duration |
| `fare` | `850.00` | Estimated fare (float) |
| `actual_fare` | `NULL` | Final fare (set after completion) |
| `route_polyline` | `"encoded_string"` | Encoded polyline for map |
| `route_steps` | `[{...}, {...}]` | Turn-by-turn directions (JSON) |
| `driver_to_pickup_polyline` | `NULL` | Set when driver accepts |
| `driver_to_pickup_distance` | `NULL` | Set when driver accepts |
| `driver_to_pickup_duration` | `NULL` | Set when driver accepts |
| `status` | `"requested"` | Initial status |
| `notes` | `"Arrive in 5 min"` | Passenger notes (nullable) |
| `rating` | `NULL` | Driver rating (set after ride) |
| `feedback` | `NULL` | Passenger feedback (nullable) |
| `requested_at` | `"2025-10-24T05:30:00Z"` | Request timestamp |
| `accepted_at` | `NULL` | When driver accepts |
| `started_at` | `NULL` | When ride starts |
| `completed_at` | `NULL` | When ride completes |
| `cancelled_at` | `NULL` | If ride is cancelled |
| `cancellation_reason` | `NULL` | Cancellation reason |
| `driver_id` | `NULL` | Set when driver accepts |

### **C. Finds Nearby Drivers**
- 📡 Searches for drivers within **10km radius** of pickup location
- ✅ Only sends to drivers with `is_available = true`
- 📊 Calculates distance from each driver to pickup point

### **D. Broadcasts to Drivers (Triple Approach)**

**Backend sends ride request using 3 methods for reliability:**

```typescript
// Method 1: Driver-specific room
io.to(`driver_${driver_id}`).emit('ride_request', rideData);

// Method 2: Driver's socket ID directly
io.to(driver_socketId).emit('ride_request', rideData);

// Method 3: All available drivers room (fallback)
io.to('available_drivers').emit('ride_request', rideData);
```

---

## 📥 STEP 3: What Your Driver App Receives

### **Event to Listen To**: `'ride_request'`

### **Complete Data Structure**:

```dart
socket.on('ride_request', (data) {
  // YOUR DRIVER APP RECEIVES THIS:
  
  final Map<String, dynamic> rideRequest = {
    // ===== RIDE IDENTIFICATION =====
    'ride_id': 'ride-abc-123-xyz',          // Unique ride ID
    'status': 'requested',                   // Current status
    'timestamp': '2025-10-24T05:30:00.000Z', // Request time
    
    // ===== PASSENGER INFORMATION =====
    'passenger_id': 'uuid-1234-5678',
    'passenger_name': 'Jane Smith',
    'passenger_phone': '+254798765432',
    'passenger_image': 'https://example.com/photo.jpg', // May be null
    
    // ===== PICKUP LOCATION =====
    'pickup_latitude': -1.286389,
    'pickup_longitude': 36.817223,
    'pickup_address': 'Nairobi CBD, Kenya',
    
    // ===== DESTINATION LOCATION =====
    'destination_latitude': -1.319167,
    'destination_longitude': 36.925278,
    'destination_address': 'JKIA Airport, Nairobi',
    
    // ===== TRIP DETAILS =====
    'distance': '15.43',              // Distance in km (string)
    'distance_text': '15.4 km',       // Human-readable
    'duration': 1200,                 // Duration in seconds (int)
    'duration_text': '20 min',        // Human-readable
    'fare': '850.00',                 // Estimated fare (string)
    
    // ===== ROUTE INFORMATION =====
    'route_polyline': 'encoded_polyline_string_abc123...',  // For map display
    'route_steps': [                  // Turn-by-turn navigation
      {
        'instruction': 'Head south on Kenyatta Avenue',
        'distance': '1.2 km',
        'duration': '3 min'
      },
      {
        'instruction': 'Turn right onto Uhuru Highway',
        'distance': '8.5 km',
        'duration': '12 min'
      }
      // ... more steps
    ],
    
    // ===== DRIVER-SPECIFIC INFO (UNIQUE TO EACH DRIVER) =====
    'estimated_arrival': '5 minutes',  // YOUR arrival time to pickup
    'driver_distance': '2.5',          // YOUR distance from pickup (km)
    
    // ===== ADDITIONAL INFO =====
    'notes': 'Please arrive in 5 minutes',  // Passenger notes (may be null)
    'requested_at': '2025-10-24T05:30:00.000Z'
  };
  
  // ===== WHAT YOUR DRIVER APP SHOULD DO =====
  // 1. ✅ Show notification/alert to driver
  // 2. 🔔 Play sound alert
  // 3. 📱 Show ride request popup/dialog with:
  //    - Passenger name & photo
  //    - Pickup & destination addresses
  //    - Distance, duration, fare
  //    - Estimated time to reach pickup
  //    - Map showing route
  // 4. ⏱️ Start 30-60 second countdown timer
  // 5. 🎯 Show "ACCEPT" and "REJECT" buttons
});
```

---

## 🎯 What Driver App Must Do Next

### **Option A: Driver Accepts Ride**

```dart
socket.emit('ride_accept', {
  'ride_id': 'ride-abc-123-xyz',        // From ride_request data
  'driver_id': 'your-driver-uuid',
  'driver_name': 'John Doe',
  'driver_phone': '+254712345678',
  'driver_vehicle': 'Toyota Camry',
  'driver_vehicle_number': 'KXX 123Y',
  'driver_rating': 4.8,
  'current_latitude': -1.290278,        // Driver's current location
  'current_longitude': 36.825556,
  'estimated_arrival': '5 minutes'
});
```

**Backend will then:**
- ✅ Update `rides` table: `status = 'accepted'`, `driver_id = your_id`, `accepted_at = timestamp`
- 📢 Notify passenger via `'ride_accepted'` event
- 🚫 Remove ride from other drivers' screens

---

### **Option B: Driver Rejects Ride**

```dart
socket.emit('ride_reject', {
  'ride_id': 'ride-abc-123-xyz',
  'driver_id': 'your-driver-uuid',
  'reason': 'Too far away'  // Optional
});
```

**Backend will then:**
- 📡 Forward request to other nearby drivers
- ❌ Remove ride from your screen

---

## 🚨 Important Implementation Notes

### **1. Handle Duplicate Requests**

You may receive the **SAME ride request multiple times** (due to triple broadcast). **Always deduplicate by `ride_id`:**

```dart
final Set<String> seenRideIds = {};

socket.on('ride_request', (data) {
  final rideId = data['ride_id'];
  
  if (seenRideIds.contains(rideId)) {
    print('⚠️ Duplicate ride request, ignoring');
    return;
  }
  
  seenRideIds.add(rideId);
  showRideRequestDialog(data);
});
```

### **2. Request Timeout**

- ⏰ Ride requests timeout after **60 seconds** (backend configured)
- 🔕 If driver doesn't respond, the request disappears
- ⏱️ Show a countdown timer to driver (60, 59, 58...)

### **3. Driver Must Be Online & Available**

To receive ride requests, ensure:
```dart
socket.emit('connect_driver', {
  'driver_id': 'your-uuid',
  'name': 'John Doe',
  'phone': '+254712345678',
  'vehicle_type': 'Sedan',
  'vehicle_number': 'KXX 123Y',
  'latitude': -1.286389,
  'longitude': 36.817223,
  'is_available': true,  // ⚠️ MUST BE TRUE to receive requests
});
```

### **4. Display Polyline on Map**

Use the `route_polyline` to show route on map:
```dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void displayRoute(String encodedPolyline) {
  PolylinePoints polylinePoints = PolylinePoints();
  List<PointLatLng> points = polylinePoints.decodePolyline(encodedPolyline);
  
  List<LatLng> polylineCoordinates = points
    .map((point) => LatLng(point.latitude, point.longitude))
    .toList();
  
  Polyline polyline = Polyline(
    polylineId: PolylineId('route'),
    color: Colors.blue,
    points: polylineCoordinates,
    width: 5,
  );
  
  // Add to map
}
```

---

## 📊 Database Query (For Reference)

If you want to query rides directly from Supabase:

```dart
// Get all requested rides (as backup to Socket.IO)
final response = await supabase
  .from('rides')
  .select('*')
  .eq('status', 'requested')
  .order('requested_at', ascending: false);

// Real-time subscription (fallback if Socket.IO fails)
final subscription = supabase
  .from('rides')
  .stream(primaryKey: ['id'])
  .eq('status', 'requested')
  .listen((List<Map<String, dynamic>> data) {
    // New ride request
  });
```

---

## 🧪 Testing Checklist

- [ ] Driver connects successfully (`connect_driver` emitted)
- [ ] Driver receives `driver_connected` confirmation
- [ ] Driver receives `ride_request` event when passenger requests ride
- [ ] All ride data displays correctly (passenger, pickup, destination, fare)
- [ ] Map shows route polyline
- [ ] Accept button emits `ride_accept` and updates ride status
- [ ] Reject button emits `ride_reject` and removes ride from screen
- [ ] Duplicate requests are ignored (same `ride_id`)
- [ ] Request disappears after 60-second timeout
- [ ] Driver doesn't receive requests when `is_available = false`

---

## 🔗 Related Files in Codebase

- **Passenger Socket Service**: `lib/services/socket_service_new.dart`
- **Backend Passenger Handler**: `tourtaxi-unified-backend/src/handlers/passengerHandler.ts`
- **Backend Driver Handler**: `tourtaxi-unified-backend/src/handlers/driverHandler.ts`
- **Ride Model**: `lib/models/ride.dart`

---

## 📞 Summary for Driver App Developer

**"Your driver app needs to listen to the `'ride_request'` event. When a passenger requests a ride, the backend automatically calculates distance, duration, fare, and route, saves everything to the `rides` table in Supabase, and broadcasts the complete ride data to all nearby available drivers. You'll receive a JSON object with all passenger info, pickup/destination locations, trip details (distance, duration, fare), route polyline for the map, and YOUR specific estimated arrival time. Display this in a popup with Accept/Reject buttons, and emit `'ride_accept'` or `'ride_reject'` based on driver's choice."**

---

🎉 **That's it! Your driver app is ready to receive ride requests!**
