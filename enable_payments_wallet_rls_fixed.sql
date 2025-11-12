-- =============================================
-- STEP 1: Create tables if they don't exist
-- =============================================

-- Create wallets table if it doesn't exist
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  balance NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Create wallet_transactions table if it doesn't exist
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('credit', 'debit')),
  amount NUMERIC NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create payments table if it doesn't exist
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
  amount NUMERIC NOT NULL,
  method TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- STEP 2: Add missing columns if needed
-- =============================================

-- Add user_id to wallets if missing
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'wallets' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE wallets ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add user_id to payments if missing
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE payments ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- =============================================
-- STEP 3: Enable RLS on all tables
-- =============================================

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- =============================================
-- STEP 4: Drop existing policies (if any)
-- =============================================

DROP POLICY IF EXISTS "Users can view their own payments" ON payments;
DROP POLICY IF EXISTS "Users can insert their own payments" ON payments;
DROP POLICY IF EXISTS "Users can update their own payments" ON payments;
DROP POLICY IF EXISTS "Users can view their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can insert their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can update their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can view their own transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Users can insert their own transactions" ON wallet_transactions;

-- =============================================
-- STEP 5: Create RLS Policies
-- =============================================

-- Payments policies
CREATE POLICY "Users can view their own payments"
  ON payments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own payments"
  ON payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own payments"
  ON payments FOR UPDATE
  USING (auth.uid() = user_id);

-- Wallets policies
CREATE POLICY "Users can view their own wallet"
  ON wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own wallet"
  ON wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own wallet"
  ON wallets FOR UPDATE
  USING (auth.uid() = user_id);

-- Wallet Transactions policies
CREATE POLICY "Users can view their own transactions"
  ON wallet_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wallets
      WHERE wallets.id = wallet_transactions.wallet_id
      AND wallets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own transactions"
  ON wallet_transactions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wallets
      WHERE wallets.id = wallet_transactions.wallet_id
      AND wallets.user_id = auth.uid()
    )
  );

-- =============================================
-- STEP 6: Create database functions
-- =============================================

-- Drop existing functions
DROP FUNCTION IF EXISTS update_wallet_balance(UUID, NUMERIC);
DROP FUNCTION IF EXISTS get_wallet_balance(UUID);

-- Function to update wallet balance
CREATE OR REPLACE FUNCTION update_wallet_balance(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS UUID AS $$
DECLARE
  v_wallet_id UUID;
BEGIN
  -- Insert wallet if doesn't exist or update existing
  INSERT INTO wallets (user_id, balance, created_at, updated_at)
  VALUES (p_user_id, p_amount, NOW(), NOW())
  ON CONFLICT (user_id) 
  DO UPDATE SET 
    balance = wallets.balance + p_amount,
    updated_at = NOW()
  RETURNING id INTO v_wallet_id;
  
  RETURN v_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get wallet balance
CREATE OR REPLACE FUNCTION get_wallet_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT balance INTO v_balance
  FROM wallets
  WHERE user_id = p_user_id;
  
  RETURN COALESCE(v_balance, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- STEP 7: Create indexes for performance
-- =============================================

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_ride_id ON payments(ride_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at DESC);

-- =============================================
-- SUCCESS MESSAGE
-- =============================================

DO $$ 
BEGIN
  RAISE NOTICE '✅ All tables, policies, and functions created successfully!';
END $$;
