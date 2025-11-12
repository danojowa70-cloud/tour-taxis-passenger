-- Update scheduled_rides table schema to support OTP verification flow

-- 1. Ensure all required columns exist
ALTER TABLE scheduled_rides
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
ADD COLUMN IF NOT EXISTS otp VARCHAR(6),
ADD COLUMN IF NOT EXISTS created_by_passenger BOOLEAN DEFAULT true;

-- 2. Update status check constraint to include all necessary statuses
ALTER TABLE scheduled_rides
DROP CONSTRAINT IF EXISTS scheduled_rides_status_check;

ALTER TABLE scheduled_rides
ADD CONSTRAINT scheduled_rides_status_check 
CHECK (status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled'));

-- 3. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_driver_id ON scheduled_rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_otp ON scheduled_rides(otp);
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_status_passenger ON scheduled_rides(status, passenger_id);

-- 4. Update RLS policies to support driver access
DROP POLICY IF EXISTS "Drivers can view available scheduled rides" ON scheduled_rides;
CREATE POLICY "Drivers can view available scheduled rides"
  ON scheduled_rides
  FOR SELECT
  USING (
    -- Drivers can see scheduled rides without a driver assigned
    (status = 'scheduled' AND driver_id IS NULL)
    OR
    -- Drivers can see their own accepted rides
    (auth.uid() = driver_id)
  );

-- 5. Allow drivers to update scheduled rides they accepted
DROP POLICY IF EXISTS "Drivers can accept scheduled rides" ON scheduled_rides;
CREATE POLICY "Drivers can accept scheduled rides"
  ON scheduled_rides
  FOR UPDATE
  USING (
    -- Driver can accept if ride is scheduled and no driver assigned
    (status = 'scheduled' AND driver_id IS NULL)
    OR
    -- Driver can update their own rides
    (auth.uid() = driver_id)
  );

-- 6. Update OTP generation trigger
DROP TRIGGER IF EXISTS generate_otp_on_confirm ON scheduled_rides;
DROP FUNCTION IF EXISTS generate_ride_otp();

CREATE OR REPLACE FUNCTION generate_ride_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate OTP when ride status changes to confirmed
  IF NEW.status = 'confirmed' AND (OLD.status = 'scheduled' OR OLD.status IS NULL) AND NEW.driver_id IS NOT NULL THEN
    NEW.otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    NEW.confirmed_at := NOW();
  END IF;
  
  -- Set started_at when ride starts
  IF NEW.status = 'in_progress' AND OLD.status = 'confirmed' THEN
    NEW.started_at := NOW();
  END IF;
  
  -- Set completed_at when ride completes
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    NEW.completed_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_otp_on_confirm
  BEFORE UPDATE ON scheduled_rides
  FOR EACH ROW
  EXECUTE FUNCTION generate_ride_otp();

-- 7. Add columns documentation
COMMENT ON COLUMN scheduled_rides.driver_id IS 'Driver who accepted the scheduled ride';
COMMENT ON COLUMN scheduled_rides.confirmed_at IS 'When driver confirmed/accepted the ride';
COMMENT ON COLUMN scheduled_rides.started_at IS 'When driver actually started the ride (after OTP verification)';
COMMENT ON COLUMN scheduled_rides.completed_at IS 'When the ride was completed';
COMMENT ON COLUMN scheduled_rides.cancellation_reason IS 'Reason for cancellation (by driver or passenger)';
COMMENT ON COLUMN scheduled_rides.otp IS '6-digit OTP for driver to verify with passenger before starting ride';
COMMENT ON COLUMN scheduled_rides.created_by_passenger IS 'Whether ride was created by passenger (vs admin or system)';
