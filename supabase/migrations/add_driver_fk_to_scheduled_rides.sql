-- Add foreign key relationship between scheduled_rides and drivers table

-- First, make sure driver_id column exists and is the right type
ALTER TABLE scheduled_rides
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL;

-- Create index on driver_id for better query performance
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_driver_id ON scheduled_rides(driver_id);

-- Add comment for documentation
COMMENT ON COLUMN scheduled_rides.driver_id IS 'Reference to the driver who accepted this scheduled ride';
