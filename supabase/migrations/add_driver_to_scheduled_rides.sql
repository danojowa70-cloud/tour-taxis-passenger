-- Add driver-related columns to scheduled_rides table
ALTER TABLE scheduled_rides
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Update status check constraint to include new statuses
ALTER TABLE scheduled_rides
DROP CONSTRAINT IF EXISTS scheduled_rides_status_check;

ALTER TABLE scheduled_rides
ADD CONSTRAINT scheduled_rides_status_check 
CHECK (status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled'));

-- Create index for driver queries
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_driver_id ON scheduled_rides(driver_id);

-- Update RLS policy to allow drivers to view scheduled rides
DROP POLICY IF EXISTS "Drivers can view available scheduled rides" ON scheduled_rides;
CREATE POLICY "Drivers can view available scheduled rides"
  ON scheduled_rides
  FOR SELECT
  USING (
    -- Drivers can see rides that are scheduled (no driver assigned)
    status = 'scheduled' AND driver_id IS NULL
    OR
    -- Drivers can see their own accepted rides
    auth.uid() = driver_id
  );

-- Update policy for drivers to accept rides
DROP POLICY IF EXISTS "Drivers can accept scheduled rides" ON scheduled_rides;
CREATE POLICY "Drivers can accept scheduled rides"
  ON scheduled_rides
  FOR UPDATE
  USING (
    -- Driver can accept if ride is scheduled and no driver assigned
    status = 'scheduled' AND driver_id IS NULL
    OR
    -- Driver can update their own rides
    auth.uid() = driver_id
  );

-- Add comment for documentation
COMMENT ON COLUMN scheduled_rides.driver_id IS 'Driver who accepted the scheduled ride';
COMMENT ON COLUMN scheduled_rides.confirmed_at IS 'When driver confirmed/accepted the ride';
COMMENT ON COLUMN scheduled_rides.started_at IS 'When driver actually started the ride';
COMMENT ON COLUMN scheduled_rides.cancellation_reason IS 'Reason for cancellation (by driver or passenger)';
