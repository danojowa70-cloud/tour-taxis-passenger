-- Add OTP column for ride verification
ALTER TABLE scheduled_rides
ADD COLUMN IF NOT EXISTS otp VARCHAR(6),
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Create index for OTP lookups
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_otp ON scheduled_rides(otp);

-- Add function to generate random 6-digit OTP
CREATE OR REPLACE FUNCTION generate_ride_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate OTP only when driver confirms the ride
  IF NEW.status = 'confirmed' AND OLD.status = 'scheduled' AND NEW.driver_id IS NOT NULL THEN
    NEW.otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-generate OTP when ride is confirmed
DROP TRIGGER IF EXISTS generate_otp_on_confirm ON scheduled_rides;
CREATE TRIGGER generate_otp_on_confirm
  BEFORE UPDATE ON scheduled_rides
  FOR EACH ROW
  EXECUTE FUNCTION generate_ride_otp();

-- Add comment for documentation
COMMENT ON COLUMN scheduled_rides.otp IS '6-digit OTP for driver to verify with passenger before starting ride';
COMMENT ON COLUMN scheduled_rides.completed_at IS 'When the ride was completed';
