-- ===========================================
-- Migration: Add vehicle_type column to rides table
-- ===========================================
-- This migration adds vehicle_type to the rides table to store
-- the passenger's requested vehicle type for ride matching
-- Author: AI Assistant
-- Date: 2025-01-09

-- Add vehicle_type column to rides table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'rides' 
        AND column_name = 'vehicle_type'
    ) THEN
        ALTER TABLE rides 
        ADD COLUMN vehicle_type TEXT;
        
        RAISE NOTICE 'Added vehicle_type column to rides table';
    ELSE
        RAISE NOTICE 'vehicle_type column already exists in rides table';
    END IF;
END $$;

-- Create index for faster vehicle type queries
CREATE INDEX IF NOT EXISTS idx_rides_vehicle_type 
ON rides(vehicle_type);

-- Add comment to document the column
COMMENT ON COLUMN rides.vehicle_type IS 'Requested vehicle type by passenger: car, suv, bike, etc. Used for driver matching.';

-- Ensure drivers table has vehicle_type (should already exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'drivers' 
        AND column_name = 'vehicle_type'
    ) THEN
        ALTER TABLE drivers 
        ADD COLUMN vehicle_type TEXT DEFAULT 'Sedan';
        
        RAISE NOTICE 'Added vehicle_type column to drivers table';
    ELSE
        RAISE NOTICE 'vehicle_type column already exists in drivers table';
    END IF;
END $$;

-- Create index on drivers.vehicle_type for faster filtering
CREATE INDEX IF NOT EXISTS idx_drivers_vehicle_type 
ON drivers(vehicle_type);

-- Add comment to document the column
COMMENT ON COLUMN drivers.vehicle_type IS 'Driver vehicle type: Car, Sedan, SUV, Bike, Motorcycle, etc.';

-- Update existing NULL vehicle types to default 'Car'
UPDATE drivers 
SET vehicle_type = 'Sedan' 
WHERE vehicle_type IS NULL;

-- Migration complete
