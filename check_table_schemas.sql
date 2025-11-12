-- Check payments table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'payments' 
ORDER BY ordinal_position;

-- Check wallets table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'wallets' 
ORDER BY ordinal_position;

-- Check wallet_transactions table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'wallet_transactions' 
ORDER BY ordinal_position;
