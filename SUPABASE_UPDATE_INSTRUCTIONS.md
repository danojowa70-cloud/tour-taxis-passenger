# Supabase Schema Updates for Scheduled Ride OTP Verification

## Summary of Changes

The following updates are needed in your Supabase database to support the complete scheduled ride OTP verification flow.

## Step-by-Step Instructions

### 1. Execute the Migration SQL

Copy the SQL from `supabase/migrations/update_scheduled_rides_schema.sql` and run it in your Supabase SQL Editor:

**Path:** Go to Supabase Dashboard → SQL Editor → Run query

The migration file includes:
- Adding missing columns (`driver_id`, `otp`, `confirmed_at`, `started_at`, `completed_at`, etc.)
- Updating status constraints to include `in_progress`
- Creating performance indexes
- Setting up RLS policies for drivers
- Updating OTP generation triggers

### 2. Verify the Schema

After running the migration, verify the `scheduled_rides` table has:

```
Columns:
- id (UUID, Primary Key)
- passenger_id (UUID, FK to users)
- driver_id (UUID, FK to users) ✅ NEW
- pickup_location, pickup_latitude, pickup_longitude
- destination_location, destination_latitude, destination_longitude
- scheduled_time
- estimated_fare, distance_meters, duration_seconds
- otp (VARCHAR(6)) ✅ NEW
- status (scheduled, confirmed, in_progress, completed, cancelled) ✅ UPDATED
- created_at, updated_at
- confirmed_at ✅ NEW
- started_at ✅ NEW
- completed_at ✅ NEW
- cancellation_reason ✅ NEW
- created_by_passenger ✅ NEW
```

### 3. Backend RPC Function (Optional but Recommended)

Create a PostgreSQL function for secure OTP verification. In Supabase SQL Editor:

```sql
CREATE OR REPLACE FUNCTION verify_scheduled_ride_otp(
  ride_id_param UUID,
  driver_id_param UUID,
  otp_param VARCHAR(6)
)
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
BEGIN
  -- Check if ride exists and belongs to driver
  IF NOT EXISTS (
    SELECT 1 FROM scheduled_rides 
    WHERE id = ride_id_param 
    AND driver_id = driver_id_param 
    AND status = 'confirmed'
  ) THEN
    RETURN QUERY SELECT FALSE::BOOLEAN, 'Ride not found or already started'::TEXT;
    RETURN;
  END IF;
  
  -- Check if OTP matches
  IF NOT EXISTS (
    SELECT 1 FROM scheduled_rides 
    WHERE id = ride_id_param 
    AND otp = otp_param
  ) THEN
    RETURN QUERY SELECT FALSE::BOOLEAN, 'Invalid OTP'::TEXT;
    RETURN;
  END IF;
  
  -- OTP is valid, update ride status
  UPDATE scheduled_rides 
  SET status = 'in_progress', started_at = NOW()
  WHERE id = ride_id_param;
  
  RETURN QUERY SELECT TRUE::BOOLEAN, 'OTP verified successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 4. Verify Real-time Subscriptions

Ensure your Supabase project has Real-time enabled for the `scheduled_rides` table:

1. Go to Supabase Dashboard
2. Navigate to Replication → Publications
3. Ensure `scheduled_rides` table is in the publication
4. This enables real-time listeners in the Flutter apps

## Table Status Flow

```
scheduled  → confirmed  → in_progress → completed
  ↓             ↓            ↓
No driver   OTP generated  Passenger
assigned    & emitted      notified
```

## Files Modified

- ✅ `lib/services/scheduled_ride_tracking_service.dart` - NEW
- ✅ `lib/screens/scheduled_rides_history_screen.dart` - UPDATED
- ✅ `lib/services/scheduled_rides_service.dart` (Driver) - UPDATED
- ✅ `supabase/migrations/update_scheduled_rides_schema.sql` - NEW

## Real-time Events

The system will now emit these events:

1. **When driver accepts ride:**
   - Table update: `status: 'scheduled' → 'confirmed'`
   - OTP auto-generated
   - Event: `scheduled:accepted`

2. **When driver verifies OTP:**
   - Table update: `status: 'confirmed' → 'in_progress'`
   - Event: `scheduled:started`
   - Passenger app: Auto-navigates to RideDetailsScreen

3. **When ride completes:**
   - Table update: `status: 'in_progress' → 'completed'`
   - Event: `scheduled:completed`

## Testing Checklist

- [ ] Run migration in Supabase
- [ ] Verify table schema updated
- [ ] Test passenger scheduling a ride
- [ ] Test driver accepting ride (OTP should auto-generate)
- [ ] Test driver entering OTP (status should change to `in_progress`)
- [ ] Verify passenger app navigates to ride details screen
- [ ] Check real-time sync works across apps

## Troubleshooting

### OTP not generating:
- Check trigger `generate_otp_on_confirm` exists
- Verify ride status actually changes to 'confirmed'

### Passenger not notified:
- Check `ride_events` table has the event inserted
- Verify real-time subscription is active
- Check `ScheduledRideTrackingService` is listening

### Status not updating:
- Verify driver_id is set when accepting ride
- Check OTP column has a value
- Ensure `in_progress` status is allowed (constraint updated)
