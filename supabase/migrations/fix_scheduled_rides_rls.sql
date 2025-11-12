-- Drop existing RLS policies
DROP POLICY IF EXISTS "Users can view their own scheduled rides" ON scheduled_rides;
DROP POLICY IF EXISTS "Users can insert their own scheduled rides" ON scheduled_rides;
DROP POLICY IF EXISTS "Users can update their own scheduled rides" ON scheduled_rides;
DROP POLICY IF EXISTS "Users can delete their own scheduled rides" ON scheduled_rides;

-- Create new policies that check against passengers table
CREATE POLICY "Users can view their own scheduled rides"
  ON scheduled_rides
  FOR SELECT
  USING (
    passenger_id IN (
      SELECT id FROM passengers WHERE auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own scheduled rides"
  ON scheduled_rides
  FOR INSERT
  WITH CHECK (
    passenger_id IN (
      SELECT id FROM passengers WHERE auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own scheduled rides"
  ON scheduled_rides
  FOR UPDATE
  USING (
    passenger_id IN (
      SELECT id FROM passengers WHERE auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own scheduled rides"
  ON scheduled_rides
  FOR DELETE
  USING (
    passenger_id IN (
      SELECT id FROM passengers WHERE auth_user_id = auth.uid()
    )
  );
