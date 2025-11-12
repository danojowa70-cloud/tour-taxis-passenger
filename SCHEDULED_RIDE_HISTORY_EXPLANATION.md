# Scheduled Ride History Feature - Complete Explanation

## Overview
The scheduled ride history feature allows passengers to view all their scheduled rides (upcoming, completed, cancelled, etc.) with full details including OTP and driver information.

---

## How It Works (Step by Step)

### 1. **When User Schedules a Ride**

**File:** `lib/screens/schedule_ride_screen.dart`
- User taps "Schedule Ride" button
- App calls `ScheduleRideNotifier.scheduleRide()`

**File:** `lib/providers/schedule_providers.dart` (lines 142-209)
```
scheduleRide() calls:
  ↓
ScheduledRidesService.scheduleRide()
```

**File:** `lib/services/scheduled_rides_service.dart` (lines 10-52)
```
scheduleRide() does:
1. Gets current authenticated passenger ID from Supabase Auth
2. Collects ride data:
   - passenger_id (the person scheduling the ride)
   - pickup_location, pickup_latitude, pickup_longitude
   - destination_location, destination_latitude, destination_longitude
   - scheduled_time (when the ride should start)
   - estimated_fare
   - status: 'scheduled' ← Starts as 'scheduled'
   
3. Inserts into Supabase table: scheduled_rides
4. Returns success/failure
```

### 2. **Database Structure**

**Table:** `scheduled_rides`
```
Columns:
- id (UUID)
- passenger_id (UUID) ← Links to the passenger who scheduled it
- driver_id (UUID) ← Links to driver who accepted it (NULL initially)
- pickup_location (text)
- pickup_latitude, pickup_longitude (float)
- destination_location (text)
- destination_latitude, destination_longitude (float)
- scheduled_time (timestamp)
- estimated_fare (numeric)
- status (text) ← 'scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled'
- otp (text) ← Generated when driver accepts
- created_at (timestamp)
- updated_at (timestamp)
```

---

## 3. **When User Views History Tab**

**File:** `lib/screens/schedule_ride_screen.dart` (lines 118-120)
```dart
userId != null 
    ? ScheduledRidesHistoryScreen(passengerId: userId)
    : const Center(child: CircularProgressIndicator())
```

Passes the current user's ID to the history screen.

---

## 4. **ScheduledRidesHistoryScreen Loads Data**

**File:** `lib/screens/scheduled_rides_history_screen.dart`

### Initialization (lines 26-38):
```dart
@override
void initState() {
  _historyFuture = _service.getScheduledRidesHistory(
    passengerId: widget.passengerId,  // ← Pass passenger ID
  );
  
  // Also start real-time tracking for when driver enters OTP
  _trackingService.listenForRideStarted(
    passengerId: widget.passengerId,
    onRideStarted: _handleRideStarted,
  );
}
```

### UI Rendering (lines 69-120):
```dart
FutureBuilder displays:
- Loading spinner (while fetching)
- Error message (if query fails)
- "No ride history" (if list is empty)
- ListView of rides (if rides exist)
```

---

## 5. **Fetching Rides - The Service**

**File:** `lib/services/scheduled_rides_history_service.dart`

### getScheduledRidesHistory() Method (lines 7-54):

```dart
Future<List<Map<String, dynamic>>> getScheduledRidesHistory({
  required String passengerId,
}) async {
  try {
    // Step 1: Query Supabase for all rides matching this passenger
    final ridesResponse = await _supabase
        .from('scheduled_rides')
        .select()                           // Get ALL columns
        .eq('passenger_id', passengerId)    // WHERE passenger_id = ?
        .order('scheduled_time', ascending: false)  // Newest first
        .limit(50);                         // Max 50 rides
    
    // Step 2: Log what we got
    debugPrint('📦 Total rides fetched: ${ridesResponse.length}');
    
    if (ridesResponse.isEmpty) {
      return [];  // No rides found
    }
    
    // Step 3: For each ride, fetch driver details separately
    List<Map<String, dynamic>> rides = 
        List<Map<String, dynamic>>.from(ridesResponse);
    
    for (int i = 0; i < rides.length; i++) {
      final driverId = rides[i]['driver_id'];  // Can be NULL initially
      
      if (driverId != null) {  // Only fetch if a driver accepted
        try {
          final driverData = await _supabase
              .from('drivers')
              .select()
              .eq('id', driverId)
              .single();
          
          // Step 4: Attach driver data to ride
          rides[i]['drivers'] = driverData;  // Add driver info to ride
        } catch (e) {
          debugPrint('⚠️ Could not fetch driver data for $driverId');
        }
      }
    }
    
    return rides;  // Return list with all data
  } catch (e) {
    debugPrint('❌ Error fetching scheduled rides history: $e');
    return [];
  }
}
```

---

## 6. **Displaying Each Ride - The Card**

**File:** `lib/screens/scheduled_rides_history_screen.dart` (lines 125-409)

### _RideHistoryCard Widget displays:

```
┌─────────────────────────────────────┐
│ 📍 PICKUP LOCATION                  │ SCHEDULED
│    Destination Location             │
├─────────────────────────────────────┤
│ 📅 Nov 05, 2025 - 3:15 PM          │
├─────────────────────────────────────┤
│ OTP to Share with Driver            │
│ 1234  [Copy]                        │ ← For 'pending' status
├─────────────────────────────────────┤
│ Driver Details                      │
│ 👤 Driver Name                      │
│ 📞 +1234567890                      │
│ 🚗 KA-01-AB-1234                    │
├─────────────────────────────────────┤
│ ℹ️ Booked on Nov 05, 2025          │
└─────────────────────────────────────┘
```

### What Each Section Shows:

1. **Header Section** (lines 147-190)
   - Pickup location (pickup_location column)
   - Destination location (destination_location column)
   - Status badge (status column)

2. **Scheduled Time** (lines 194-205)
   - Formatted date/time from scheduled_time column

3. **OTP Section** (lines 209-291)
   - Shows for: 'pending', 'confirmed', 'in_progress', 'completed' rides
   - If status is 'pending'/'confirmed': "OTP to Share with Driver"
   - If status is 'in_progress'/'completed': "OTP Given to Driver"
   - Displays: otp column value
   - Has copy button to clipboard

4. **Driver Info** (lines 296-372)
   - Shows for: 'completed' and 'in_progress' rides
   - Displays: drivers table data (name, phone, vehicle_number)

5. **Booking Info** (lines 377-390)
   - Shows when ride was booked (created_at column)

---

## 7. **Real-Time Updates**

**File:** `lib/services/scheduled_ride_tracking_service.dart`

While viewing history, the app listens for updates:

```dart
_trackingService.listenForRideStarted(
  passengerId: widget.passengerId,
  onRideStarted: _handleRideStarted,
);

// When driver enters OTP and ride starts:
_handleRideStarted() {
  ref.read(rideFlowProvider.notifier).setRideId(rideId);
  Navigator.of(context).pushNamed('/ride-details');
  // ↑ Auto-navigates to ride details screen
}
```

---

## 8. **Pull-to-Refresh**

**File:** `lib/screens/scheduled_rides_history_screen.dart` (lines 102-108)

```dart
RefreshIndicator(
  onRefresh: () async {
    setState(() {
      _historyFuture = _service.getScheduledRidesHistory(
        passengerId: widget.passengerId,
      );
    });
  },
  child: ListView.builder(...)
);
```

User pulls down to refresh the history list.

---

## Data Flow Diagram

```
┌─────────────────┐
│  Schedule Ride  │
│    (UI Form)    │
└────────┬────────┘
         │ User taps "Schedule Ride"
         ↓
┌─────────────────────────────────┐
│ ScheduleRideNotifier            │
│ scheduleRide()                  │
└────────┬────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────┐
│ ScheduledRidesService                    │
│ scheduleRide()                           │
│ - Gets passenger_id from Auth            │
│ - Creates ride object with status='...' │
└────────┬─────────────────────────────────┘
         │
         ↓
    Supabase
 ┌──────────────────────────┐
 │ scheduled_rides table    │
 │ INSERT new record        │
 └──────────────────────────┘

═══════════════════════════════════════════════

┌──────────────────────┐
│  History Tab Opened  │
└────────┬─────────────┘
         │
         ↓
┌───────────────────────────────────────────┐
│ ScheduledRidesHistoryService              │
│ getScheduledRidesHistory(passengerId)     │
│ - WHERE passenger_id = current_user       │
│ - Fetch ALL columns for matching rides    │
│ - For each ride with driver_id, fetch     │
│   driver details from drivers table       │
└────────┬────────────────────────────────────┘
         │
         ↓
    Supabase
 ┌──────────────────────────┐
 │ SELECT * FROM            │
 │ scheduled_rides          │
 │ WHERE passenger_id = ?   │
 │                          │
 │ SELECT * FROM drivers    │
 │ WHERE id IN (driver_ids) │
 └──────────────────────────┘
         │
         ↓
┌────────────────────────────────────┐
│ List<Map<String, dynamic>>         │
│ [                                  │
│   {ride1_data},                    │
│   {ride2_data},                    │
│   ...                              │
│ ]                                  │
└────────┬───────────────────────────┘
         │
         ↓
┌────────────────────────────────────────┐
│ _RideHistoryCard                       │
│ - Display each ride as a Card widget   │
│ - Show OTP, driver info, etc.          │
└────────────────────────────────────────┘
```

---

## Status Lifecycle

```
When Ride is First Scheduled:
  status = 'scheduled'
  otp = NULL
  driver_id = NULL

When Driver Accepts (via driver app):
  status = 'confirmed'
  otp = Generated (e.g., "1234")
  driver_id = Set to accepting driver

When Driver Enters OTP at Pickup:
  status = 'in_progress'
  otp = Remains same

When Ride Completes:
  status = 'completed'
  otp = Remains same

If Passenger Cancels:
  status = 'cancelled'
```

---

## Why Two Rides Are Showing

The history shows:
1. **First ride:** The one you scheduled earlier (status='scheduled' or 'confirmed')
2. **Second ride:** Another ride you scheduled (possibly with different time)

Both are fetched from the database because:
- Both have the same `passenger_id` (your ID)
- Both exist in the `scheduled_rides` table
- The query fetches ALL rides (no status filtering) sorted by newest first

---

## Summary

**Scheduled Ride History = Complete Passenger Journey Log**

- ✅ Shows ALL rides you've scheduled
- ✅ Shows ride details (location, time, fare)
- ✅ Shows OTP when driver confirms
- ✅ Shows driver info when they accept
- ✅ Auto-updates when driver enters OTP (real-time)
- ✅ Pull-to-refresh to get latest data
