-- ===========================================
-- Step 1: DROP the existing function
-- ===========================================
DROP FUNCTION IF EXISTS public.get_nearby_drivers(double precision, double precision, double precision, text);

-- ===========================================
-- Step 2: CREATE the fixed function (without vehicle_make)
-- ===========================================
CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  lat double precision,
  lng double precision,
  radius_km double precision DEFAULT 10.0,
  desired_vehicle text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  email text,
  rating numeric,
  vehicle_type text,
  vehicle_model text,
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
    d.vehicle_type,
    d.vehicle_model,
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
    AND (
      -- If no vehicle type specified, return all drivers
      desired_vehicle IS NULL
      -- Exact match (case-insensitive)
      OR lower(trim(d.vehicle_type)) = lower(trim(desired_vehicle))
      -- Handle 'car' and 'sedan' as synonyms for compatibility
      OR (lower(trim(desired_vehicle)) = 'car' AND lower(trim(d.vehicle_type)) IN ('car', 'sedan'))
      OR (lower(trim(desired_vehicle)) = 'sedan' AND lower(trim(d.vehicle_type)) IN ('car', 'sedan'))
      -- Handle 'bike' variants (bike, motorcycle, etc.)
      OR (lower(trim(desired_vehicle)) = 'bike' AND lower(trim(d.vehicle_type)) IN ('bike', 'motorcycle', 'motorbike'))
      OR (lower(trim(desired_vehicle)) = 'motorcycle' AND lower(trim(d.vehicle_type)) IN ('bike', 'motorcycle', 'motorbike'))
      -- Exact SUV match
      OR (lower(trim(desired_vehicle)) = 'suv' AND lower(trim(d.vehicle_type)) = 'suv')
    )
    AND ST_DWithin(
      ST_MakePoint(lng, lat)::geography,
      ST_MakePoint(d.current_longitude, d.current_latitude)::geography,
      radius_km * 1000  -- Convert km to meters
    )
  ORDER BY distance_km ASC
  LIMIT 20;  -- Return up to 20 nearest drivers
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
