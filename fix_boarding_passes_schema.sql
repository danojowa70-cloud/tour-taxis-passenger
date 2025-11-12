-- =============================================
-- 🔧 FIX BOARDING PASSES TABLE SCHEMA
-- =============================================
-- This script adds missing columns to existing boarding_passes table

-- Add user_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'boarding_passes' 
        AND column_name = 'user_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.boarding_passes 
        ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Added user_id column to boarding_passes table';
    ELSE
        RAISE NOTICE 'user_id column already exists in boarding_passes table';
    END IF;
END
$$;

-- Add arrival_time column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'boarding_passes' 
        AND column_name = 'arrival_time'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.boarding_passes 
        ADD COLUMN arrival_time TIMESTAMP WITH TIME ZONE;
        
        RAISE NOTICE 'Added arrival_time column to boarding_passes table';
    ELSE
        RAISE NOTICE 'arrival_time column already exists in boarding_passes table';
    END IF;
END
$$;

-- Add updated_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'boarding_passes' 
        AND column_name = 'updated_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.boarding_passes 
        ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        
        RAISE NOTICE 'Added updated_at column to boarding_passes table';
    ELSE
        RAISE NOTICE 'updated_at column already exists in boarding_passes table';
    END IF;
END
$$;

-- Make user_id NOT NULL after adding the column
-- (We do this separately to handle existing rows)
DO $$
BEGIN
    -- First, check if there are any rows without user_id
    IF EXISTS (SELECT 1 FROM public.boarding_passes WHERE user_id IS NULL) THEN
        -- Get the first available user ID to assign to orphaned records
        DECLARE
            default_user_id UUID;
        BEGIN
            SELECT id INTO default_user_id FROM auth.users LIMIT 1;
            
            IF default_user_id IS NOT NULL THEN
                UPDATE public.boarding_passes 
                SET user_id = default_user_id 
                WHERE user_id IS NULL;
                
                RAISE NOTICE 'Updated % rows with default user_id: %', 
                    (SELECT COUNT(*) FROM public.boarding_passes WHERE user_id = default_user_id),
                    default_user_id;
            ELSE
                RAISE WARNING 'No users found in auth.users table to assign to orphaned boarding passes';
            END IF;
        END;
    END IF;

    -- Now make the column NOT NULL if it isn't already
    BEGIN
        ALTER TABLE public.boarding_passes 
        ALTER COLUMN user_id SET NOT NULL;
        
        RAISE NOTICE 'Set user_id column as NOT NULL';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'user_id column may already be NOT NULL or constraint failed: %', SQLERRM;
    END;
END
$$;

-- Add indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_boarding_passes_user_id ON public.boarding_passes (user_id);
CREATE INDEX IF NOT EXISTS idx_boarding_passes_departure_time ON public.boarding_passes (departure_time);
CREATE INDEX IF NOT EXISTS idx_boarding_passes_status ON public.boarding_passes (status);
CREATE INDEX IF NOT EXISTS idx_boarding_passes_booking_id ON public.boarding_passes (booking_id);

-- Enable RLS if not already enabled
ALTER TABLE public.boarding_passes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies if they don't exist
DO $$
BEGIN
    -- Create policies only if they don't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'boarding_passes' 
        AND policyname = 'Users can view their own boarding passes'
    ) THEN
        CREATE POLICY "Users can view their own boarding passes" ON public.boarding_passes
            FOR SELECT USING (auth.uid() = user_id);
        RAISE NOTICE 'Created SELECT policy for boarding_passes';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'boarding_passes' 
        AND policyname = 'Users can insert their own boarding passes'
    ) THEN
        CREATE POLICY "Users can insert their own boarding passes" ON public.boarding_passes
            FOR INSERT WITH CHECK (auth.uid() = user_id);
        RAISE NOTICE 'Created INSERT policy for boarding_passes';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'boarding_passes' 
        AND policyname = 'Users can update their own boarding passes'
    ) THEN
        CREATE POLICY "Users can update their own boarding passes" ON public.boarding_passes
            FOR UPDATE USING (auth.uid() = user_id);
        RAISE NOTICE 'Created UPDATE policy for boarding_passes';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'boarding_passes' 
        AND policyname = 'Users can delete their own boarding passes'
    ) THEN
        CREATE POLICY "Users can delete their own boarding passes" ON public.boarding_passes
            FOR DELETE USING (auth.uid() = user_id);
        RAISE NOTICE 'Created DELETE policy for boarding_passes';
    END IF;
END
$$;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.boarding_passes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.boarding_passes TO anon;

-- Create function to update updated_at timestamp if it doesn't exist
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

-- Show table structure after updates
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'boarding_passes'
ORDER BY ordinal_position;

RAISE NOTICE '✅ Boarding passes table schema update completed!';