-- ===========================================
-- 🔧 FORCE FIX: Completely remove and recreate function
-- ===========================================

-- First, let's see what columns actually exist in your drivers table
-- Run this first to see your actual table structure:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'drivers' ORDER BY column_name;

-- Drop all possible versions of the function
DROP FUNCTION IF EXISTS public.get_nearby_drivers(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS get_nearby_drivers(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.get_driver_count_in_area(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS get_driver_count_in_area(double precision, double precision, double precision) CASCADE;

-- Clear any cached plans
DISCARD ALL;

-- Create the simplest possible version first - just basic columns
CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  lat double precision,
  lng double precision,
  radius_km double precision DEFAULT 10.0
)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  vehicle_type text,
  vehicle_number text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  is_online boolean,
  is_available boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.name,
    d.phone,
    d.vehicle_type,
    d.vehicle_number,
    d.current_latitude as latitude,
    d.current_longitude as longitude,
    ST_Distance(
      ST_MakePoint(lng, lat)::geography,
      ST_MakePoint(d.current_longitude, d.current_latitude)::geography
    ) / 1000.0 as distance_km,
    d.is_online,
    d.is_available
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
  ORDER BY distance_km ASC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Simple count function
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_count_in_area(double precision, double precision, double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.get_driver_count_in_area(double precision, double precision, double precision) TO authenticated;