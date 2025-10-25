-- ===========================================
-- 🔧 FIXED: get_nearby_drivers Function for Existing Schema
-- ===========================================
-- This function works with your existing 'drivers' table structure

CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  lat double precision,
  lng double precision,
  radius_km double precision DEFAULT 10.0
)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  email text,
  rating numeric,
  vehicle_make text,
  vehicle_model text,
  vehicle_plate text,
  vehicle_type text,
  vehicle_number text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  is_online boolean,
  is_available boolean,
  last_seen timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.name,
    d.phone,
    d.email,
    d.rating,
    d.vehicle_make,
    d.vehicle_model,
    d.vehicle_plate,
    d.vehicle_type,
    d.vehicle_number,
    d.current_latitude as latitude,
    d.current_longitude as longitude,
    ST_Distance(
      ST_MakePoint(lng, lat)::geography,
      ST_MakePoint(d.current_longitude, d.current_latitude)::geography
    ) / 1000.0 as distance_km,
    d.is_online,
    d.is_available,
    d.last_location_update as last_seen
  FROM drivers d
  WHERE
    d.is_online = TRUE
    AND d.is_available = TRUE
    AND d.current_latitude IS NOT NULL
    AND d.current_longitude IS NOT NULL
    AND d.last_location_update > NOW() - INTERVAL '30 minutes'  -- Driver was active in last 30 minutes
    AND ST_DWithin(
      ST_MakePoint(lng, lat)::geography,
      ST_MakePoint(d.current_longitude, d.current_latitude)::geography,
      radius_km * 1000  -- Convert km to meters
    )
  ORDER BY distance_km ASC
  LIMIT 20;  -- Return up to 20 nearest drivers
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- 🔧 ALSO NEEDED: get_driver_count_in_area Function
-- ===========================================

CREATE OR REPLACE FUNCTION public.get_driver_count_in_area(
  lat double precision,
  lng double precision,
  radius_km double precision DEFAULT 10.0
)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::integer
    FROM drivers d
    WHERE
      d.is_online = TRUE
      AND d.is_available = TRUE
      AND d.current_latitude IS NOT NULL
      AND d.current_longitude IS NOT NULL
      AND d.last_location_update > NOW() - INTERVAL '30 minutes'
      AND ST_DWithin(
        ST_MakePoint(lng, lat)::geography,
        ST_MakePoint(d.current_longitude, d.current_latitude)::geography,
        radius_km * 1000
      )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- 🔧 TEST QUERIES - Run these to debug
-- ===========================================

-- 1. Check if any drivers exist
-- SELECT COUNT(*) as total_drivers FROM drivers;

-- 2. Check if any drivers are online
-- SELECT COUNT(*) as online_drivers FROM drivers WHERE is_online = true;

-- 3. Check if any drivers have location data
-- SELECT COUNT(*) as drivers_with_location FROM drivers WHERE current_latitude IS NOT NULL AND current_longitude IS NOT NULL;

-- 4. Check recent driver activity
-- SELECT COUNT(*) as recent_active FROM drivers WHERE last_location_update > NOW() - INTERVAL '30 minutes';

-- 5. Test the function with sample coordinates (replace with real coordinates)
-- SELECT * FROM get_nearby_drivers(37.7749, -122.4194, 50.0);

-- 6. Get driver count in area
-- SELECT get_driver_count_in_area(37.7749, -122.4194, 50.0);