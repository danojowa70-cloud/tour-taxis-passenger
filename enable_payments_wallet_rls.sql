-- Enable RLS on payments and wallet tables
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their own payments" ON payments;
DROP POLICY IF EXISTS "Users can insert their own payments" ON payments;
DROP POLICY IF EXISTS "Users can view their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can insert their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can update their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can view their own transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Users can insert their own transactions" ON wallet_transactions;

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

-- Create function to update wallet balance
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

-- Create function to get wallet balance
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
