-- =============================================
-- 🗑️ DROP AND RECREATE BOARDING PASSES TABLE
-- =============================================
-- This script completely recreates the boarding_passes table with proper structure

-- Drop the existing table completely
DROP TABLE IF EXISTS public.boarding_passes CASCADE;

-- Recreate the table with correct structure
CREATE TABLE public.boarding_passes (
    id TEXT PRIMARY KEY,  -- Changed from UUID to TEXT to match Flutter app
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ride_event_id VARCHAR(100) NOT NULL,
    passenger_name VARCHAR(255) NOT NULL,
    booking_id VARCHAR(50) UNIQUE NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('chopper','privateJet','cruise')),
    destination VARCHAR(255) NOT NULL,
    origin VARCHAR(255),
    departure_time TIMESTAMPTZ NOT NULL,
    arrival_time TIMESTAMPTZ,
    operator_name VARCHAR(255) NOT NULL,
    operator_logo TEXT DEFAULT '',
    qr_code TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','boarding','departed','completed','cancelled')),
    seat_number VARCHAR(10),
    gate VARCHAR(10),
    terminal VARCHAR(50),
    fare NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_boarding_passes_user_id ON public.boarding_passes(user_id);
CREATE INDEX idx_boarding_passes_ride_event_id ON public.boarding_passes(ride_event_id);
CREATE INDEX idx_boarding_passes_booking_id ON public.boarding_passes(booking_id);
CREATE INDEX idx_boarding_passes_departure_time ON public.boarding_passes(departure_time);
CREATE INDEX idx_boarding_passes_status ON public.boarding_passes(status);

-- Enable Row Level Security
ALTER TABLE public.boarding_passes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own boarding passes" 
ON public.boarding_passes
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own boarding passes" 
ON public.boarding_passes
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own boarding passes" 
ON public.boarding_passes
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own boarding passes" 
ON public.boarding_passes
FOR DELETE 
USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT ALL ON public.boarding_passes TO authenticated;
GRANT ALL ON public.boarding_passes TO anon;

-- Create function for auto-updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_boarding_passes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for auto-updating updated_at
CREATE TRIGGER trigger_boarding_passes_updated_at
    BEFORE UPDATE ON public.boarding_passes
    FOR EACH ROW
    EXECUTE FUNCTION update_boarding_passes_updated_at();

-- Insert test data if there are users available
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Try to get a user ID for testing
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
            seat_number,
            gate,
            terminal,
            fare
        ) VALUES (
            'test_bp_' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
            test_user_id,
            'ride_test_' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
            'Test Passenger',
            'BP' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
            'chopper',
            'Mombasa',
            'Nairobi',
            NOW() + INTERVAL '1 day',
            NOW() + INTERVAL '1 day 2 hours',
            'SkyTour Helicopters',
            'https://example.com/logo.png',
            'BOARDING_PASS:test:' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
            'upcoming',
            '1A',
            'H5',
            'Helipad A',
            45000.00
        ) ON CONFLICT (booking_id) DO NOTHING;
        
        RAISE NOTICE '✅ Test boarding pass created for user: %', test_user_id;
    ELSE
        RAISE NOTICE '⚠️  No users found - create a user account first to test boarding passes';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Error creating test data: %', SQLERRM;
END
$$;

-- Verify table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'boarding_passes'
ORDER BY ordinal_position;

-- Show created policies
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename = 'boarding_passes';

-- Final success message
SELECT '✅ Boarding passes table recreated successfully!' as status;