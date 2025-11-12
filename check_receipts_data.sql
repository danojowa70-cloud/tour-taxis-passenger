-- Run these queries in Supabase SQL Editor to debug receipts issue

-- 1. Check what columns exist in rides table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'rides' 
ORDER BY ordinal_position;

-- 2. Check if there are any completed/cancelled rides
SELECT id, passenger_id, status, created_at, fare 
FROM rides 
WHERE status IN ('completed', 'cancelled')
LIMIT 10;

-- 3. Check passengers table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'passengers' 
ORDER BY ordinal_position;

-- 4. Check if passengers have auth_user_id
SELECT id, auth_user_id, name, phone 
FROM passengers 
LIMIT 10;

-- 5. Check scheduled_rides structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'scheduled_rides' 
ORDER BY ordinal_position;

-- 6. Check boarding_passes structure (premium bookings)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'boarding_passes' 
ORDER BY ordinal_position;

-- 7. Sample data from boarding_passes (since premium works)
SELECT id, user_id, passenger_name, status, fare, created_at 
FROM boarding_passes 
LIMIT 5;

-- 8. Try to join rides with passengers to see the relationship
SELECT 
  r.id as ride_id,
  r.passenger_id,
  r.status,
  r.fare,
  p.id as passenger_table_id,
  p.auth_user_id,
  p.name as passenger_name
FROM rides r
LEFT JOIN passengers p ON r.passenger_id = p.id
WHERE r.status IN ('completed', 'cancelled')
LIMIT 10;
