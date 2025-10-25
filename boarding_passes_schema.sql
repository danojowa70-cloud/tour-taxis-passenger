-- ===========================================
-- 🛳️ BOARDING PASSES TABLE SCHEMA
-- ===========================================

-- Create the boarding_passes table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.boarding_passes (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ride_event_id TEXT NOT NULL,
    passenger_name TEXT NOT NULL,
    booking_id TEXT NOT NULL UNIQUE,
    vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('chopper', 'privateJet', 'cruise')),
    destination TEXT NOT NULL,
    origin TEXT,
    departure_time TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_time TIMESTAMP WITH TIME ZONE,
    operator_name TEXT NOT NULL,
    operator_logo TEXT DEFAULT '',
    qr_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'boarding', 'departed', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    seat_number TEXT,
    gate TEXT,
    terminal TEXT,
    fare NUMERIC(10,2)
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_boarding_passes_user_id ON public.boarding_passes (user_id);
CREATE INDEX IF NOT EXISTS idx_boarding_passes_departure_time ON public.boarding_passes (departure_time);
CREATE INDEX IF NOT EXISTS idx_boarding_passes_status ON public.boarding_passes (status);
CREATE INDEX IF NOT EXISTS idx_boarding_passes_booking_id ON public.boarding_passes (booking_id);

-- Enable RLS (Row Level Security)
ALTER TABLE public.boarding_passes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can view their own boarding passes" ON public.boarding_passes;
    DROP POLICY IF EXISTS "Users can insert their own boarding passes" ON public.boarding_passes;
    DROP POLICY IF EXISTS "Users can update their own boarding passes" ON public.boarding_passes;
    DROP POLICY IF EXISTS "Users can delete their own boarding passes" ON public.boarding_passes;

    -- Create new policies
    CREATE POLICY "Users can view their own boarding passes" ON public.boarding_passes
        FOR SELECT USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert their own boarding passes" ON public.boarding_passes
        FOR INSERT WITH CHECK (auth.uid() = user_id);

    CREATE POLICY "Users can update their own boarding passes" ON public.boarding_passes
        FOR UPDATE USING (auth.uid() = user_id);

    CREATE POLICY "Users can delete their own boarding passes" ON public.boarding_passes
        FOR DELETE USING (auth.uid() = user_id);
END
$$;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.boarding_passes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.boarding_passes TO anon;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_boarding_passes_updated_at ON public.boarding_passes;
CREATE TRIGGER update_boarding_passes_updated_at
    BEFORE UPDATE ON public.boarding_passes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Test data insertion (you can remove this after testing)
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Try to get a user ID from auth.users for testing
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Insert a test boarding pass
        INSERT INTO public.boarding_passes (
            id,
            user_id,
            ride_event_id,
            passenger_name,
            booking_id,
            vehicle_type,
            destination,
            origin,
            departure_time,
            arrival_time,
            operator_name,
            operator_logo,
            qr_code,
            status,
            fare
        ) VALUES (
            'test_bp_' || extract(epoch from now())::bigint,
            test_user_id,
            'ride_test_' || extract(epoch from now())::bigint,
            'Test Passenger',
            'BP' || extract(epoch from now())::bigint,
            'chopper',
            'Mombasa',
            'Nairobi',
            NOW() + INTERVAL '1 day',
            NOW() + INTERVAL '1 day 2 hours',
            'SkyTour Helicopters',
            'https://example.com/logo.png',
            'BOARDING_PASS:test:' || extract(epoch from now())::bigint,
            'upcoming',
            45000.00
        ) ON CONFLICT (booking_id) DO NOTHING;
        
        RAISE NOTICE 'Test boarding pass inserted successfully for user: %', test_user_id;
    ELSE
        RAISE NOTICE 'No users found in auth.users table for testing';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error inserting test data: %', SQLERRM;
END
$$;