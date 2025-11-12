# Scheduled Rides Feature Setup

## 🎯 Overview
This feature allows passengers to schedule rides in advance and drivers to view and accept them.

## 📋 Setup Steps

### 1. Update Supabase Database Schema

Run this SQL in your Supabase SQL Editor:

```bash
# Location: supabase/migrations/add_driver_to_scheduled_rides.sql
```

This adds:
- `driver_id` - driver who accepts the ride
- `confirmed_at` - when driver accepted
- `started_at` - when ride actually started
- `cancellation_reason` - cancellation details
- Updated RLS policies for drivers

### 2. Driver App Integration

The driver app now has:

**New Files Created:**
- `lib/services/scheduled_rides_service.dart` - Service to manage scheduled rides
- `lib/screens/scheduled_rides/scheduled_rides_screen.dart` - UI for drivers

**Add to Navigation:**
Add a button in the driver's home screen to navigate to scheduled rides:

```dart
// In home_screen.dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScheduledRidesScreen(),
      ),
    );
  },
  icon: const Icon(Icons.schedule),
  label: const Text('Scheduled Rides'),
)
```

## 🚀 How It Works

### For Passengers:
1. Schedule a ride with pickup, dropoff, date, and time
2. Ride is saved as "scheduled" status
3. Receive notification when a driver accepts

### For Drivers:
1. View available scheduled rides in "Available" tab
2. See ride details: passenger info, locations, time, fare
3. Accept rides they want to take
4. View accepted rides in "My Rides" tab
5. Start the ride when it's time
6. Real-time notifications for new scheduled rides

## 📱 Features

- **Real-time Updates**: Drivers get instant notifications for new scheduled rides
- **Two Tabs**: 
  - Available Rides (all unassigned)
  - My Rides (rides you accepted)
- **Pull to Refresh**: Update the list anytime
- **Ride Details**: Full info including passenger name, phone, locations, time, fare, distance
- **Accept/Cancel**: Drivers can accept available rides or cancel their accepted rides

## 🔔 Notifications

The service includes hooks for push notifications:
- When driver accepts → notify passenger
- When driver cancels → notify passenger
- When new ride is scheduled → notify all online drivers

## 🗄️ Database Schema

```sql
scheduled_rides:
  - id (UUID, primary key)
  - passenger_id (UUID, references users)
  - driver_id (UUID, references users, nullable)
  - pickup_location, pickup_latitude, pickup_longitude
  - destination_location, destination_latitude, destination_longitude
  - scheduled_time (timestamp)
  - estimated_fare, distance_meters, duration_seconds
  - status: scheduled | confirmed | in_progress | completed | cancelled
  - confirmed_at, started_at, cancellation_reason
  - created_at, updated_at
```

## 🔐 Security

Row Level Security (RLS) policies ensure:
- Passengers can only see their own scheduled rides
- Drivers can see available (unassigned) rides
- Drivers can see their accepted rides
- Only the assigned driver can update their accepted rides
