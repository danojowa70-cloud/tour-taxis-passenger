-- ===========================================
-- 🔧 SIMPLE FIX: No PostGIS, Force Drop All Functions
-- ===========================================

-- This will work even without PostGIS extension

-- Force drop ALL versions of the function
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all functions with this name regardless of signature
    FOR r IN 
        SELECT 'DROP FUNCTION IF EXISTS ' || oid::regprocedure || ' CASCADE;' as drop_stmt
        FROM pg_proc 
        WHERE proname = 'get_nearby_drivers'
    LOOP
        EXECUTE r.drop_stmt;
    END LOOP;
    
    FOR r IN 
        SELECT 'DROP FUNCTION IF EXISTS ' || oid::regprocedure || ' CASCADE;' as drop_stmt
        FROM pg_proc 
        WHERE proname = 'get_driver_count_in_area'
    LOOP
        EXECUTE r.drop_stmt;
    END LOOP;
END
$$;

-- Clear all cached plans
DISCARD ALL;

-- Create simple function using basic math (no PostGIS required)
CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  lat double precision,
  lng double precision,
  radius_km double precision DEFAULT 10.0
)
RETURNS TABLE (
  id uuid,
  name character varying,
  phone character varying,
  email character varying,
  rating numeric,
  vehicle_type character varying,
  vehicle_model character varying,
  vehicle_number character varying,
  vehicle_color character varying,
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
    d.vehicle_color,
    d.current_latitude as latitude,
    d.current_longitude as longitude,
    -- Simple distance calculation using Haversine approximation
    ROUND(
      (6371 * acos(
        cos(radians(lat)) * cos(radians(d.current_latitude)) *
        cos(radians(d.current_longitude) - radians(lng)) +
        sin(radians(lat)) * sin(radians(d.current_latitude))
      ))::numeric, 2
    ) as distance_km,
    d.is_online,
    d.is_available,
    d.last_location_update as last_seen
  FROM drivers d
  WHERE
    d.is_online = TRUE
    AND d.is_available = TRUE
    AND d.current_latitude IS NOT NULL
    AND d.current_longitude IS NOT NULL
    AND d.last_location_update > NOW() - INTERVAL '30 minutes'
    -- Simple bounding box check for performance
    AND d.current_latitude BETWEEN lat - (radius_km / 111.0) AND lat + (radius_km / 111.0)
    AND d.current_longitude BETWEEN lng - (radius_km / (111.0 * cos(radians(lat)))) AND lng + (radius_km / (111.0 * cos(radians(lat))))
  ORDER BY 
    -- Order by simple distance calculation
    (6371 * acos(
      cos(radians(lat)) * cos(radians(d.current_latitude)) *
      cos(radians(d.current_longitude) - radians(lng)) +
      sin(radians(lat)) * sin(radians(d.current_latitude))
    )) ASC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Simple count function (no PostGIS)
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
      -- Simple bounding box check
      AND d.current_latitude BETWEEN lat - (radius_km / 111.0) AND lat + (radius_km / 111.0)
      AND d.current_longitude BETWEEN lng - (radius_km / (111.0 * cos(radians(lat)))) AND lng + (radius_km / (111.0 * cos(radians(lat))))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_count_in_area(double precision, double precision, double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.get_driver_count_in_area(double precision, double precision, double precision) TO authenticated;