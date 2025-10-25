# 🧪 Manual Testing for Driver Matching Issue

## Step 1: Execute the Fixed SQL Function in Supabase
1. Go to your Supabase Dashboard > SQL Editor
2. Copy and paste the content from `get_nearby_drivers_fix.sql`
3. Run the SQL to create the correct function

## Step 2: Debug Database State
Run these SQL queries in Supabase to check your data:

```sql
-- 1. Check total drivers
SELECT COUNT(*) as total_drivers FROM drivers;

-- 2. Check online drivers  
SELECT COUNT(*) as online_drivers FROM drivers WHERE is_online = true;

-- 3. Check drivers with location
SELECT COUNT(*) as drivers_with_location 
FROM drivers 
WHERE current_latitude IS NOT NULL AND current_longitude IS NOT NULL;

-- 4. Check recent activity (last 30 minutes)
SELECT COUNT(*) as recent_active 
FROM drivers 
WHERE last_location_update > NOW() - INTERVAL '30 minutes';

-- 5. See actual driver data
SELECT id, name, is_online, is_available, current_latitude, current_longitude, last_location_update
FROM drivers 
ORDER BY last_location_update DESC 
LIMIT 10;
```

## Step 3: Test the get_nearby_drivers Function Directly
Replace the coordinates with your actual test location:

```sql
-- Test with a large radius first (100km)
SELECT * FROM get_nearby_drivers(37.7749, -122.4194, 100.0);

-- Test driver count function
SELECT get_driver_count_in_area(37.7749, -122.4194, 100.0);
```

## Step 4: Test Your API Endpoints
Test your backend API directly:

```bash
# Test nearby drivers endpoint (replace with your backend URL and coordinates)
curl "http://localhost:3000/api/rides/nearby-drivers?lat=37.7749&lng=-122.4194&radius=50"

# Test creating a ride with coordinates
curl -X POST "http://localhost:3000/api/rides" \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "test-passenger-123",
    "pickup": "123 Test Street",
    "drop": "456 Test Avenue", 
    "pickupLat": 37.7749,
    "pickupLng": -122.4194
  }'
```

## Step 5: Common Issues & Solutions

### Issue 1: No drivers in database
**Solution:** Add test drivers or ensure your driver app is creating driver records

### Issue 2: Drivers exist but are offline
**Solution:** Ensure driver app calls `update_driver_online_status(true, driver_id, true)`

### Issue 3: Drivers are online but have no location
**Solution:** Ensure driver app calls `update_driver_location(driver_id, lat, lng)`

### Issue 4: get_nearby_drivers function doesn't exist
**Solution:** Run the SQL from `get_nearby_drivers_fix.sql` in Supabase

### Issue 5: Function exists but returns no results
**Possible causes:**
- Wrong coordinates (try larger radius)
- No recent driver activity (check last_location_update)
- Drivers not marked as available
- PostGIS extension not enabled

## Step 6: Add Test Data (if no drivers exist)
```sql
-- Insert a test driver
INSERT INTO drivers (
  id, 
  name, 
  phone, 
  current_latitude, 
  current_longitude, 
  is_online, 
  is_available,
  last_location_update
) VALUES (
  gen_random_uuid(),
  'Test Driver',
  '+1234567890',
  37.7749,  -- San Francisco coordinates
  -122.4194,
  true,
  true,
  NOW()
);
```

## Step 7: Check Logs
Look at your backend logs for:
- Function call errors
- Database connection issues  
- Parameter validation errors

## Expected Results
If everything works correctly:
- SQL queries should return driver counts > 0
- get_nearby_drivers should return driver data
- API endpoints should return JSON with driver arrays
- Ride creation should log "Found X nearby drivers"