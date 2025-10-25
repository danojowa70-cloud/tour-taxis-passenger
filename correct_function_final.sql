-- ===========================================
-- ✅ FINAL CORRECT FUNCTION - Matches Your Exact Table Structure
-- ===========================================

-- Drop all possible versions
DROP FUNCTION IF EXISTS public.get_nearby_drivers(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS get_nearby_drivers(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.get_driver_count_in_area(double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS get_driver_count_in_area(double precision, double precision, double precision) CASCADE;

-- Clear cache
DISCARD ALL;

-- Create function with your EXACT column names
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

-- Count function
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_count_in_area(double precision, double precision, double precision) TO anon;
GRANT EXECUTE ON FUNCTION public.get_driver_count_in_area(double precision, double precision, double precision) TO authenticated;