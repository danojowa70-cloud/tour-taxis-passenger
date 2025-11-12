-- Create scheduled_rides table
CREATE TABLE IF NOT EXISTS scheduled_rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Pickup location details
  pickup_location TEXT NOT NULL,
  pickup_latitude DOUBLE PRECISION NOT NULL,
  pickup_longitude DOUBLE PRECISION NOT NULL,
  
  -- Destination location details
  destination_location TEXT NOT NULL,
  destination_latitude DOUBLE PRECISION NOT NULL,
  destination_longitude DOUBLE PRECISION NOT NULL,
  
  -- Schedule details
  scheduled_time TIMESTAMPTZ NOT NULL,
  
  -- Ride details
  estimated_fare DECIMAL(10, 2) NOT NULL,
  distance_meters INTEGER,
  duration_seconds INTEGER,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'cancelled', 'completed')),
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_passenger_id ON scheduled_rides(passenger_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_scheduled_time ON scheduled_rides(scheduled_time);
CREATE INDEX IF NOT EXISTS idx_scheduled_rides_status ON scheduled_rides(status);

-- Enable Row Level Security (RLS)
ALTER TABLE scheduled_rides ENABLE ROW LEVEL SECURITY;

-- Create policy for users to view their own scheduled rides
CREATE POLICY "Users can view their own scheduled rides"
  ON scheduled_rides
  FOR SELECT
  USING (auth.uid() = passenger_id);

-- Create policy for users to insert their own scheduled rides
CREATE POLICY "Users can insert their own scheduled rides"
  ON scheduled_rides
  FOR INSERT
  WITH CHECK (auth.uid() = passenger_id);

-- Create policy for users to update their own scheduled rides
CREATE POLICY "Users can update their own scheduled rides"
  ON scheduled_rides
  FOR UPDATE
  USING (auth.uid() = passenger_id);

-- Create policy for users to delete their own scheduled rides
CREATE POLICY "Users can delete their own scheduled rides"
  ON scheduled_rides
  FOR DELETE
  USING (auth.uid() = passenger_id);

-- Create a trigger to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_scheduled_rides_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER scheduled_rides_updated_at
  BEFORE UPDATE ON scheduled_rides
  FOR EACH ROW
  EXECUTE FUNCTION update_scheduled_rides_updated_at();
