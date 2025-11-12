# DRIVER APP INTEGRATION PROMPT

## Overview
This document explains how the **Passenger App** communicates with the **Driver App** in the TourTaxi system. Use this to configure the Driver App to properly receive and respond to ride requests.

---

## 🏗️ System Architecture

```
┌─────────────────┐                    ┌──────────────────────┐                    ┌─────────────────┐
│  Passenger App  │                    │   Backend Server     │                    │   Driver App    │
│   (Flutter)     │◄──────────────────►│   (Socket.IO +       │◄──────────────────►│   (Flutter)     │
│                 │                    │    Supabase)         │                    │                 │
└─────────────────┘                    └──────────────────────┘                    └─────────────────┘
         │                                       │                                          │
         │                                       │                                          │
         └───────────── Supabase Realtime ──────┴──────────────────────────────────────────┘
```

---

## 🔌 Connection Details

### Backend Server URL
```
https://tourtaxi-unified-backend.onrender.com
```

### Transport Protocol
- **Primary**: Socket.IO (WebSocket)
- **Fallback**: Supabase Realtime subscriptions

---

## 📡 Communication Flow: Passenger → Driver

### **Step 1: Driver Goes Online**

**DRIVER APP MUST DO THIS FIRST:**

```dart
// Driver connects to Socket.IO server
socket.emit('connect_driver', {
  'driver_id': 'driver_uuid',
  'name': 'John Doe',
  'phone': '+254712345678',
  'vehicle_type': 'Sedan',
  'vehicle_number': 'KXX 123Y',
  'vehicle_make': 'Toyota',
  'vehicle_model': 'Camry',
  'vehicle_year': 2020,
  'vehicle_color': 'Black',
  'vehicle_plate': 'KXX 123Y',
  'latitude': -1.286389,    // Current driver location
  'longitude': 36.817223,
  'rating': 4.8,
  'is_available': true      // MUST be true to receive requests
});
```

**Backend Response:**
```dart
// Driver listens for confirmation
socket.on('driver_connected', (data) {
  print('Driver connected: ${data['driver_id']}');
  // Backend confirms driver is now online and available
});
```

---

### **Step 2: Passenger Requests a Ride**

**PASSENGER APP EMITS:**

```dart
socket.emit('ride_request', {
  'passenger_id': 'passenger_uuid',
  'passenger_name': 'Jane Smith',
  'passenger_phone': '+254798765432',
  'passenger_image': 'https://example.com/photo.jpg', // Optional
  'pickup_latitude': 50.8467,
  'pickup_longitude': 4.3525,
  'pickup_address': 'Grand Place, Brussels',
  'destination_latitude': 50.9010,
  'destination_longitude': 4.4844,
  'destination_address': 'Brussels Airport',
  'notes': 'Please arrive in 5 minutes',  // Optional
  'fare': '38.50',  // Estimated fare (calculated by passenger app)
  'ride_id': 'ride_uuid'  // Optional, backend generates if not provided
});
```

---

### **Step 3: Backend Processes & Broadcasts to Drivers**

**BACKEND DOES AUTOMATICALLY:**

1. **Validates ride data**
2. **Calculates accurate distance/duration** using Google Maps/OSRM
3. **Calculates fare** if not provided
4. **Saves ride to Supabase database** (rides table)
5. **Finds nearby available drivers** within 10km radius using PostGIS
6. **Broadcasts to ALL nearby drivers** using TRIPLE approach:

```typescript
// APPROACH 1: Send to driver-specific room
io.to(`driver_${driver_id}`).emit('ride_request', rideData);

// APPROACH 2: Send to driver's socket ID directly
io.to(driver_socketId).emit('ride_request', rideData);

// APPROACH 3: Broadcast to all available drivers (fallback)
io.to('available_drivers').emit('ride_request', rideData);
```

---

### **Step 4: Driver Receives Ride Request**

**DRIVER APP MUST LISTEN TO THIS EVENT:**

```dart
socket.on('ride_request', (data) {
  // DRIVER RECEIVES THIS DATA:
  final ride = {
    'ride_id': 'unique_ride_id',
    'passenger_id': 'passenger_uuid',
    'passenger_name': 'Jane Smith',
    'passenger_phone': '+254798765432',
    'passenger_image': 'https://...', // May be null
    
    // Pickup location
    'pickup_latitude': 50.8467,
    'pickup_longitude': 4.3525,
    'pickup_address': 'Grand Place, Brussels',
    
    // Destination
    'destination_latitude': 50.9010,
    'destination_longitude': 4.4844,
    'destination_address': 'Brussels Airport',
    
    // Trip details
    'distance': '5.43',          // in km
    'distance_text': '5.4 km',
    'duration': 840,             // in seconds
    'duration_text': '14 min',
    'fare': '38.50',
    
    // Route information
    'route_polyline': 'encoded_polyline_string', // For map display
    'route_steps': [...],        // Turn-by-turn directions
    
    // Driver-specific info
    'estimated_arrival': '5 minutes',  // Time to reach pickup
    'driver_distance': '2.5',          // Driver's distance from pickup (km)
    
    // Status
    'status': 'requested',
    'notes': 'Please arrive in 5 minutes',
    'requested_at': '2025-10-23T08:30:00.000Z',
    'timestamp': '2025-10-23T08:30:00.000Z'
  };
  
  // DRIVER APP SHOULD:
  // 1. Show notification/popup to driver
  // 2. Display ride details (pickup, destination, fare)
  // 3. Show "Accept" and "Reject" buttons
  // 4. Play sound alert
  // 5. Start countdown timer (usually 30-60 seconds to respond)
});
```

---

### **Step 5: Driver Accepts or Rejects Ride**

**OPTION A: DRIVER ACCEPTS RIDE**

```dart
socket.emit('ride_accept', {
  'ride_id': 'ride_uuid',
  'driver_id': 'driver_uuid',
  'driver_name': 'John Doe',
  'driver_phone': '+254712345678',
  'driver_vehicle': 'Toyota Camry - KXX 123Y',
  'driver_rating': 4.8,
  'current_latitude': -1.286389,   // Driver's current location
  'current_longitude': 36.817223,
  'estimated_arrival': '5 minutes'
});
```

**Backend Response:**
```dart
socket.on('ride_accepted', (data) {
  // Backend confirms acceptance and notifies passenger
  print('Ride accepted successfully');
  // Driver should now navigate to pickup location
});
```

**OPTION B: DRIVER REJECTS RIDE**

```dart
socket.emit('ride_reject', {
  'ride_id': 'ride_uuid',
  'driver_id': 'driver_uuid',
  'reason': 'Too far away'  // Optional
});
```

---

### **Step 6: Passenger Receives Acceptance**

**PASSENGER APP AUTOMATICALLY RECEIVES:**

```dart
socket.on('ride_accepted', (data) {
  // Passenger sees:
  // - Driver details (name, photo, rating, vehicle)
  // - Driver's current location on map
  // - Estimated arrival time
  // - "Driver is on the way" message
});
```

---

## 🚗 Real-Time Location Updates

### **Driver Must Send Location Updates**

```dart
// Driver app should send location every 3-5 seconds while on ride
socket.emit('driver_location_update', {
  'driver_id': 'driver_uuid',
  'ride_id': 'ride_uuid',  // If currently on a ride
  'latitude': -1.286400,
  'longitude': 36.817300,
  'heading': 45.0,         // Direction in degrees (0-360)
  'speed': 15.5,           // Speed in m/s
  'timestamp': DateTime.now().toIso8601String()
});
```

### **Passenger Receives Location Updates**

```dart
socket.on('driver_location', (data) {
  // Passenger sees driver moving on map in real-time
  updateDriverMarkerOnMap(
    latitude: data['latitude'],
    longitude: data['longitude'],
    heading: data['heading']
  );
});
```

---

## 🔄 Complete Ride Lifecycle Events

### **1. Ride Requested**
- **Passenger emits**: `ride_request`
- **Driver receives**: `ride_request`

### **2. Ride Accepted**
- **Driver emits**: `ride_accept`
- **Passenger receives**: `ride_accepted`
- **Backend sends**: Driver details, ETA

### **3. Driver Arrived at Pickup**
- **Driver emits**: `driver_arrived`
```dart
socket.emit('driver_arrived', {
  'ride_id': 'ride_uuid',
  'driver_id': 'driver_uuid',
  'latitude': -1.286389,
  'longitude': 36.817223
});
```
- **Passenger receives**: `driver_arrived`

### **4. Ride Started (Passenger Picked Up)**
- **Driver emits**: `ride_start`
```dart
socket.emit('ride_start', {
  'ride_id': 'ride_uuid',
  'driver_id': 'driver_uuid',
  'started_at': DateTime.now().toIso8601String()
});
```
- **Passenger receives**: `ride_started`

### **5. Ride Completed**
- **Driver emits**: `ride_complete`
```dart
socket.emit('ride_complete', {
  'ride_id': 'ride_uuid',
  'driver_id': 'driver_uuid',
  'actual_fare': '42.00',  // Final fare (may differ from estimate)
  'completed_at': DateTime.now().toIso8601String()
});
```
- **Passenger receives**: `ride_completed`

### **6. Passenger Rates Driver**
- **Passenger emits**: `ride_rating`
```dart
socket.emit('ride_rating', {
  'ride_id': 'ride_uuid',
  'rating': 5,  // 1-5 stars
  'feedback': 'Great driver, very professional!'  // Optional
});
```
- **Driver receives**: `rating_received`

### **7. Ride Cancelled**
- **Either party emits**: `ride_cancel`
```dart
socket.emit('ride_cancel', {
  'ride_id': 'ride_uuid',
  'cancelled_by': 'driver' or 'passenger',
  'driver_id': 'driver_uuid',
  'passenger_id': 'passenger_uuid',
  'reason': 'Passenger not responding'
});
```
- **Other party receives**: `ride_cancelled`

---

## 🔊 Important Socket.IO Events for Driver App

### **Events Driver MUST Listen To:**

```dart
// 1. Connection confirmation
socket.on('driver_connected', (data) { });

// 2. Incoming ride requests (MOST IMPORTANT)
socket.on('ride_request', (data) { });

// 3. Ride cancellation by passenger
socket.on('ride_cancelled', (data) { });

// 4. Passenger rating submitted
socket.on('rating_received', (data) { });

// 5. Error handling
socket.on('error', (data) { });

// 6. Connection status
socket.on('connect', () { print('Connected to server'); });
socket.on('disconnect', () { print('Disconnected from server'); });
socket.on('connect_error', (error) { print('Connection error: $error'); });
```

### **Events Driver MUST Emit:**

```dart
// 1. Connect as driver (on app start)
socket.emit('connect_driver', { ... });

// 2. Update availability status
socket.emit('driver_availability', {
  'driver_id': 'driver_uuid',
  'is_available': true/false
});

// 3. Send location updates (every 3-5 seconds)
socket.emit('driver_location_update', { ... });

// 4. Accept ride
socket.emit('ride_accept', { ... });

// 5. Reject ride
socket.emit('ride_reject', { ... });

// 6. Arrive at pickup
socket.emit('driver_arrived', { ... });

// 7. Start ride
socket.emit('ride_start', { ... });

// 8. Complete ride
socket.emit('ride_complete', { ... });

// 9. Cancel ride
socket.emit('ride_cancel', { ... });
```

---

## 💾 Supabase Database Integration (Backup Channel)

### **Driver can also listen to Supabase realtime:**

```dart
// Subscribe to rides table for new ride requests
final subscription = supabase
  .from('rides')
  .stream(primaryKey: ['id'])
  .eq('status', 'requested')
  .listen((List<Map<String, dynamic>> data) {
    // New ride request received
    // This is a backup if Socket.IO fails
  });

// Subscribe to ride_events table for status changes
final eventsSubscription = supabase
  .from('ride_events')
  .stream(primaryKey: ['id'])
  .listen((List<Map<String, dynamic>> data) {
    // Handle ride events
  });
```

---

## 🧪 Testing Driver App Integration

### **Test Sequence:**

1. **Driver goes online:**
   - Emit `connect_driver`
   - Verify `driver_connected` received
   - Check driver shows as online in database

2. **Wait for ride request:**
   - Have passenger emit `ride_request`
   - Driver should receive `ride_request` event
   - Verify ride details displayed correctly

3. **Accept ride:**
   - Driver emits `ride_accept`
   - Verify passenger receives `ride_accepted`
   - Check ride status = "accepted" in database

4. **Send location updates:**
   - Emit `driver_location_update` every 5 seconds
   - Verify passenger sees driver moving on map

5. **Complete ride lifecycle:**
   - Emit `driver_arrived`
   - Emit `ride_start`
   - Emit `ride_complete`
   - Verify passenger receives all events

---

## 🚨 Critical Implementation Requirements

### **1. Socket.IO Connection:**
```dart
import 'package:socket_io_client/socket_io_client.dart' as io;

final socket = io.io(
  'https://tourtaxi-unified-backend.onrender.com',
  io.OptionBuilder()
    .setTransports(['websocket'])
    .enableAutoConnect()
    .enableForceNew()
    .setTimeout(10000)
    .setReconnectionDelay(1000)
    .setReconnectionDelayMax(5000)
    .setReconnectionAttempts(5)
    .build()
);

socket.connect();
```

### **2. Join Driver Rooms:**
```dart
// After connecting, driver should join rooms
socket.emit('connect_driver', { ... });

// Backend automatically adds driver to:
// - 'driver_{driver_id}' room (personal room)
// - 'available_drivers' room (if is_available = true)
```

### **3. Handle Multiple Ride Requests:**
```dart
// Driver may receive SAME ride request multiple times (due to triple broadcast)
// Driver app MUST deduplicate by ride_id

final Set<String> seenRideIds = {};

socket.on('ride_request', (data) {
  final rideId = data['ride_id'];
  
  if (seenRideIds.contains(rideId)) {
    print('Duplicate ride request, ignoring');
    return;
  }
  
  seenRideIds.add(rideId);
  showRideRequestDialog(data);
});
```

### **4. Timeout Handling:**
```dart
// Ride requests timeout after 60 seconds
// If driver doesn't respond, request disappears
// Driver app should show countdown timer

socket.on('ride_request', (data) {
  showRideRequestWithTimer(
    data: data,
    timeoutSeconds: 60,
    onTimeout: () {
      print('Ride request expired');
      // Hide dialog automatically
    }
  );
});
```

---

## 📋 Checklist for Driver App AI

Use this checklist to ensure driver app is properly configured:

- [ ] Socket.IO client library installed (`socket_io_client` package)
- [ ] Connection to `https://tourtaxi-unified-backend.onrender.com` established
- [ ] Driver emits `connect_driver` on app start with all required fields
- [ ] Driver listens to `ride_request` event
- [ ] Driver shows notification/alert when `ride_request` received
- [ ] Driver displays ride details: pickup, destination, fare, distance
- [ ] Driver can accept ride by emitting `ride_accept`
- [ ] Driver can reject ride by emitting `ride_reject`
- [ ] Driver sends location updates every 3-5 seconds during ride
- [ ] Driver emits `driver_arrived` when reaching pickup location
- [ ] Driver emits `ride_start` when passenger enters vehicle
- [ ] Driver emits `ride_complete` when trip finishes
- [ ] Driver handles `ride_cancelled` event from passenger
- [ ] Driver app deduplicates multiple `ride_request` for same ride_id
- [ ] Driver app reconnects automatically if connection drops
- [ ] Driver app has fallback Supabase realtime subscription

---

## 🔗 Related Files Reference

**Passenger App:**
- `lib/services/socket_service_new.dart` - Socket.IO service
- `lib/services/ride_service.dart` - Supabase ride service
- `lib/screens/ride_searching_screen.dart` - Ride request UI

**Backend:**
- `tourtaxi-unified-backend/src/handlers/passengerHandler.ts` - Passenger events
- `tourtaxi-unified-backend/src/handlers/driverHandler.ts` - Driver events
- `tourtaxi-unified-backend/src/server.ts` - Socket.IO server setup

**Database:**
- Tables: `rides`, `drivers`, `passengers`, `ride_events`
- Functions: `get_nearby_drivers`, `update_driver_location_and_status`

---

## 🆘 Support & Debugging

**Test Backend Connection:**
```bash
curl https://tourtaxi-unified-backend.onrender.com/health
```

**View Backend Logs:**
- Check Render.com dashboard
- Look for "Ride request sent to drivers" logs

**Common Issues:**
1. **Driver not receiving requests**: Check `is_available = true` and `is_online = true`
2. **Duplicate notifications**: Implement ride_id deduplication
3. **Connection drops**: Enable auto-reconnection in Socket.IO options
4. **Location not updating**: Verify `driver_location_update` emit frequency

---

**END OF DRIVER APP INTEGRATION PROMPT**
