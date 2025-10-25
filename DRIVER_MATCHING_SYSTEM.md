# 🚖 TourTaxi Driver Matching System

## Overview
This document explains how the TourTaxi passenger app finds and matches with online drivers using the `active_drivers` table/view.

## Database Structure

### active_drivers Table/View
```sql
CREATE TABLE active_drivers (
  id UUID PRIMARY KEY,                    -- Driver ID
  name TEXT,
  phone TEXT,
  email TEXT,
  rating NUMERIC,
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_plate TEXT,
  vehicle_info TEXT,
  is_online BOOLEAN DEFAULT FALSE,        -- Driver online status
  is_available BOOLEAN DEFAULT TRUE,      -- Driver availability (not on a ride)
  last_seen TIMESTAMP WITH TIME ZONE,     -- Last activity timestamp
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
);
```

### driver_locations Table
```sql
CREATE TABLE driver_locations (
  driver_id UUID REFERENCES drivers(id),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  updated_at TIMESTAMP WITH TIME ZONE
);
```

## How Driver Matching Works

### 1. Passenger Requests a Ride
```
┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ Passenger       │    │ RideService         │    │ Database Function   │
│ Requests Ride   ├───►│ createRide()        ├───►│ get_nearby_drivers()│
│                 │    │                     │    │                     │
└─────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### 2. Database Function Filters Drivers
The `get_nearby_drivers()` function:
- Joins `active_drivers` with `driver_locations`
- Filters by `is_online = TRUE` and `is_available = TRUE`
- Checks `last_seen > NOW() - INTERVAL '10 minutes'` (recently active)
- Uses geographic distance calculation with `ST_Distance()`
- Orders by distance and limits to 20 nearest drivers

### 3. Driver Status Management

#### For Driver Apps:
```dart
// When driver goes online
await driverStatusService.goOnline(driverId);

// When driver goes offline  
await driverStatusService.goOffline(driverId);

// When driver accepts a ride (becomes unavailable)
await driverStatusService.setBusy(driverId);

// When driver completes a ride (becomes available again)
await driverStatusService.setAvailable(driverId);
```

#### Database Function:
```sql
-- Updates driver online/availability status
SELECT update_driver_online_status(
  'driver-uuid-here',
  true,  -- is_online
  true   -- is_available
);
```

### 4. Real-time Location Updates
```dart
// Drivers should continuously update their location
await driverStatusService.updateDriverLocation(
  driverId: driverId,
  latitude: currentLat,
  longitude: currentLng,
  heading: heading,
  speed: speed,
);
```

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE DRIVER MATCHING FLOW                        │
└─────────────────────────────────────────────────────────────────────────────┘

1. PASSENGER SIDE:
   ┌─────────────────┐    ┌─────────────────────┐
   │ Select Pickup & │    │ Confirm Ride        │
   │ Destination     ├───►│ Details             │
   │                 │    │                     │
   └─────────────────┘    └─────────────────────┘
                                   │
                                   ▼
2. BACKEND PROCESSING:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ RideService.createRide() calls:                                        │
   │                                                                         │
   │ await _client.rpc('get_nearby_drivers', {                              │
   │   'lat': pickupLat,                                                     │
   │   'lng': pickupLng,                                                     │
   │   'radius_km': 10.0                                                     │
   │ })                                                                      │
   └─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
3. DATABASE QUERY:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ SELECT d.*, dl.latitude, dl.longitude, ST_Distance(...) as distance_km │
   │ FROM active_drivers ad                                                  │
   │ JOIN driver_locations dl ON ad.id = dl.driver_id                       │
   │ WHERE                                                                   │
   │   ad.is_online = TRUE                                                   │
   │   AND ad.is_available = TRUE                                            │
   │   AND ad.last_seen > NOW() - INTERVAL '10 minutes'                     │
   │   AND ST_DWithin(passenger_location, driver_location, 10km)            │
   │ ORDER BY distance_km ASC                                                │
   │ LIMIT 20;                                                               │
   └─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
4. DRIVER NOTIFICATION:
   ┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
   │ Found Drivers   │    │ Create Ride Events  │    │ Notify Drivers via  │
   │ (Online & Near) ├───►│ for Each Driver     ├───►│ Real-time Stream    │
   │                 │    │                     │    │                     │
   └─────────────────┘    └─────────────────────┘    └─────────────────────┘
                                                               │
                                                               ▼
5. DRIVER RESPONSE:
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ First driver to accept gets the ride:                                   │
   │ • Driver status changed to is_available = FALSE                        │
   │ • Ride status updated to 'accepted'                                     │
   │ • Passenger notified via ride events stream                            │
   │ • Other drivers notified that ride is no longer available              │
   └─────────────────────────────────────────────────────────────────────────┘
```

## Setup Instructions

### 1. Execute SQL Functions
Run the SQL script in your Supabase database:
```sql
-- Execute the contents of database_functions.sql
```

### 2. Update Your App
The ride service has already been updated to use the new function and properly filter online drivers.

### 3. Test the System
```dart
// Test finding nearby drivers
final nearbyDrivers = await rideService.getNearbyDrivers(
  lat: 37.7749,
  lng: -122.4194,
  radiusKm: 5.0,
);

// Test getting driver count
final count = await driverStatusService.getOnlineDriverCount(
  lat: 37.7749,
  lng: -122.4194,
  radiusKm: 10.0,
);
```

## Key Benefits

1. **Only Online Drivers**: System only considers drivers who are `is_online = TRUE`
2. **Availability Check**: Filters out drivers who are `is_available = FALSE` (on rides)
3. **Activity Verification**: Only includes drivers active in last 10 minutes
4. **Geographic Efficiency**: Uses spatial indexing for fast proximity queries
5. **Real-time Updates**: Driver status changes are immediately reflected

## Troubleshooting

### No Drivers Found
1. Check if drivers have `is_online = TRUE` and `is_available = TRUE`
2. Verify driver locations are recent (within 10 minutes)
3. Increase search radius if needed
4. Check if drivers exist in the search area

### Drivers Not Receiving Notifications
1. Ensure drivers are subscribed to ride events stream
2. Check driver's last_seen timestamp is recent
3. Verify ride events are being created correctly

### Performance Issues
1. Ensure indexes are created (run the SQL script)
2. Monitor query performance on large datasets
3. Consider reducing search radius for busy areas