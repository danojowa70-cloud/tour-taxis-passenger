# Map Display Troubleshooting Guide

## Issue: Map Showing Wrong Location / Zoomed Out to Africa

### Problem Description
The map on the Ride Details screen shows markers very far away (e.g., in Africa instead of India), and the camera is zoomed out showing the entire world instead of focusing on the ride location.

### Root Causes

#### 1. **Invalid Destination Coordinates**
The most common cause is incorrect coordinates being stored in the database or provider state.

**Symptoms:**
- Red destination marker appears in Africa (around Ghana/Nigeria at 0°N, 0°E)
- Map is extremely zoomed out showing multiple continents
- Driver marker (blue) shows in correct location but destination is far away

**Solution:**
- Check the coordinates being passed when creating the ride
- Coordinates should be for India region: 
  - Latitude: 8°N to 37°N (e.g., 23.0225 for Ahmedabad)
  - Longitude: 68°E to 97°E (e.g., 72.5714 for Ahmedabad)
- Coordinates near (0, 0) indicate placeholder/uninitialized values

**Debugging:**
```dart
// Check console logs for coordinate validation warnings:
// ⚠️ Invalid destination coordinates: 0.0, 0.0
// ⚠️ Coordinates outside expected region: 6.6, -1.6
```

#### 2. **Missing Driver Location**
If driver location is not broadcast or received, the map won't know where to focus.

**Symptoms:**
- Only pickup/destination markers show, no blue driver marker
- Map defaults to initial position (0, 0)
- Console shows: "Driver location: null"

**Solution:**
- Ensure driver app is broadcasting location every 5 seconds
- Check socket connection on both apps
- Verify backend is relaying `driver_location_update` events

#### 3. **Bounds Calculation Including Invalid Points**
The map tries to fit all markers in view, but if one marker is at (0,0) or far away, it zooms out excessively.

**Solution:**
- Implemented coordinate validation in passenger app
- Invalid coordinates are now filtered out before adding markers
- Map focuses only on valid points

---

## Fixes Implemented (v2.0)

### 1. **Coordinate Validation**
```dart
bool _isValidCoordinate(double lat, double lng) {
  // Reject coordinates outside valid ranges
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  
  // Reject origin point (0,0) - common placeholder
  if (lat == 0 && lng == 0) return false;
  
  // For India-based app, validate region
  if (lat < 5 || lat > 40 || lng < 65 || lng > 100) return false;
  
  return true;
}
```

All coordinates are now validated before creating markers. Invalid coordinates are logged but not displayed.

### 2. **Smart Marker Display**
```dart
markers: {
  // Always show driver (if location available)
  if (_driverLatLng != null) Marker(...),
  
  // Before ride starts: show pickup only
  if (!_rideStarted && pickup != null) Marker(...),
  
  // After ride starts: show destination only
  if (_rideStarted && dest != null) Marker(...),
}
```

Only relevant markers are shown based on ride status, reducing clutter and focusing the map correctly.

### 3. **Improved Camera Positioning**
```dart
onMapCreated: (c) async {
  _mapController = c;
  
  // Priority: Focus on driver if available, otherwise pickup
  LatLng? focusPoint = _driverLatLng ?? pickup;
  
  if (focusPoint != null) {
    final pointsToFit = [
      focusPoint,
      if (_rideStarted) dest else pickup,
      ...effectivePolyline.take(10),
    ];
    
    // Fit all points with proper padding
    final bounds = _computeBounds(pointsToFit);
    if (bounds != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }
}
```

Camera now intelligently focuses on the most relevant points:
- **Before ride starts**: Driver → Pickup route
- **After ride starts**: Current location → Destination route

### 4. **Enhanced Logging**
```dart
dev.log('📍 Current coordinates - Pickup: $pickup, Dest: $dest, Driver: $_driverLatLng');
dev.log('🚗 Driver location update: $lat, $lng');
dev.log('📍 Distance from old position: ${distance} meters');
```

Comprehensive logging helps debug coordinate issues in real-time.

---

## How to Debug Map Issues

### Step 1: Check Console Logs

Open the passenger app and look for these logs:

```
[RideDetailsScreen] 📍 Current coordinates - Pickup: LatLng(23.0225, 72.5714), Dest: LatLng(23.0489, 72.5078), Driver: LatLng(23.0300, 72.5600)
```

**What to check:**
- ✅ **Good**: All coordinates are in 20-25° latitude, 70-75° longitude range (Gujarat region)
- ❌ **Bad**: Destination shows `LatLng(0.0, 0.0)` or negative longitude like `LatLng(6.6, -1.6)`

### Step 2: Check Socket Connection

Look for socket events:

```
[SocketService] 📍 Sent location update: 23.0225, 72.5714 (ride: abc123)
[RideDetailsScreen] 📍 Driver location update received
[RideDetailsScreen] 🚗 Driver location update: 23.0227, 72.5716
[RideDetailsScreen] ✅ Driver marker and camera updated successfully
```

**What to check:**
- ✅ Driver app is sending updates every 5 seconds
- ✅ Passenger app is receiving updates
- ✅ Coordinates are valid and changing (driver is moving)

### Step 3: Check Database

Query the rides table:

```sql
SELECT 
  id, 
  pickup_latitude, 
  pickup_longitude, 
  destination_latitude, 
  destination_longitude,
  status
FROM rides
WHERE id = 'your-ride-id';
```

**Expected values:**
- Pickup: 23.0225, 72.5714 (example for Ahmedabad)
- Destination: 23.0489, 72.5078 (example)
- Status: 'accepted' or 'started'

**Problem values:**
- Destination: 0.0, 0.0 (uninitialized)
- Destination: 6.6, -1.6 (placeholder from Google Places autocomplete?)

### Step 4: Check Provider State

Add temporary logging in `ride_flow_providers.dart`:

```dart
dev.log('Destination LatLng: ${destinationLatLng}');
dev.log('Destination Address: ${destination}');
```

Ensure the destination coordinates are set correctly when user selects location.

---

## Common Issues & Solutions

### Issue 1: Destination marker in Africa

**Cause:** Destination coordinates are (0, 0) or invalid

**Fix:**
1. Check where destination is being set (likely in location picker)
2. Ensure geocoding is working correctly
3. Validate coordinates before saving to database
4. The passenger app now filters out invalid coordinates automatically

**Workaround:** Even if backend has invalid data, the passenger app will now skip showing that marker.

---

### Issue 2: No driver marker visible

**Cause:** Driver location not being broadcast or received

**Fix:**
1. **Driver App**: Check console for `🚗 Broadcast location` logs every 5 seconds
2. **Passenger App**: Check console for `📍 Driver location update received` logs
3. Verify socket connection: `[SocketService] Socket connected successfully`
4. Check ride status is `accepted` or `started` (broadcasting only happens during active rides)

---

### Issue 3: Map zoomed out showing whole world

**Cause:** Bounds calculation includes points at (0, 0) or very far apart

**Fix:**
- Implemented in v2.0: Coordinate validation prevents invalid points from affecting bounds
- Map now focuses on driver → pickup before ride starts
- After ride starts, focuses on current location → destination

---

### Issue 4: Driver marker not moving smoothly

**Cause:** Location updates arriving but animation not working

**Fix:**
1. Check animation is running: Look for state updates in console
2. Ensure location updates are spaced 5+ seconds apart (too frequent causes jitter)
3. Verify `_animateMarkerToPosition()` is being called
4. Check previous animation is canceled before starting new one

**Expected behavior:**
- Driver marker moves smoothly over 1 second (30 frames)
- Camera follows driver with smooth animation
- No jumping or teleporting

---

## Testing Checklist

### Before Ride Starts
- [ ] Map shows driver marker (blue) and pickup marker (green)
- [ ] No destination marker shown yet
- [ ] Camera focused on driver → pickup route
- [ ] Driver marker updates every 5 seconds
- [ ] Driver marker animates smoothly when location changes

### After Ride Starts (OTP Verified)
- [ ] Map shows driver marker (blue) and destination marker (red)
- [ ] Pickup marker no longer shown
- [ ] Camera focused on current location → destination route
- [ ] Route polyline updates to show path to destination
- [ ] Driver marker continues updating smoothly

### Edge Cases
- [ ] Invalid coordinates don't cause map to zoom out
- [ ] Map handles missing driver location gracefully
- [ ] Socket disconnection doesn't crash app
- [ ] Map works on both emulator and physical device

---

## Performance Considerations

### Map Rendering
- Only 2-3 markers shown at once (driver + pickup/destination)
- Polyline limited to 10 points for bounds calculation
- Camera animations are smooth and not excessive

### Location Updates
- Driver broadcasts every 5 seconds (optimal balance)
- Passenger animates marker over 1 second (30 FPS)
- Old animations canceled before starting new ones

### Memory Management
- Timers properly disposed in `dispose()`
- Map controller disposed when screen closes
- Socket subscriptions cleaned up

---

## Quick Reference: Coordinate Ranges

### Valid India Coordinates
- **Latitude**: 8°N to 37°N (8.0 to 37.0)
- **Longitude**: 68°E to 97°E (68.0 to 97.0)

### Major Cities (Examples)
- **Ahmedabad**: 23.0225, 72.5714
- **Mumbai**: 19.0760, 72.8777
- **Delhi**: 28.6139, 77.2090
- **Bangalore**: 12.9716, 77.5946
- **Chennai**: 13.0827, 80.2707

### Invalid Coordinates (Will be filtered)
- **(0, 0)**: Gulf of Guinea, Africa (placeholder)
- **(6.6, -1.6)**: Ghana, West Africa (Google Places error?)
- **(-34.397, 150.644)**: Australia (wrong country)
- **(90, 0)**: North Pole (invalid)

---

## Contact & Support

If issues persist after applying these fixes:
1. Check console logs for red error messages
2. Verify all coordinates in database are within India region
3. Test with physical device (better GPS accuracy)
4. Ensure both apps are running latest version with socket fixes
