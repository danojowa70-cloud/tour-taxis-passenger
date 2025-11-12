# Fix RLS Error - Quick Guide

## ❌ Error You Got
```
ERROR: 42703: column "user_id" does not exist
```

## 🔍 What This Means
Your `payments`, `wallets`, or `wallet_transactions` tables don't have a `user_id` column.

## ✅ Solution

### Step 1: Run the Fixed SQL Script
Use `enable_payments_wallet_rls_fixed.sql` instead of the original one.

**In Supabase:**
1. Go to **SQL Editor**
2. **DELETE** the old SQL (if you pasted it)
3. Copy and paste `enable_payments_wallet_rls_fixed.sql`
4. Click **Run**

### Step 2: What the Fixed Script Does
✅ Creates tables if they don't exist
✅ Adds missing columns if needed (including `user_id`)
✅ Enables RLS safely
✅ Creates all policies
✅ Creates database functions
✅ Creates indexes for performance

### Step 3: Verify It Worked
After running the script, check:

1. **Check Tables Exist:**
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name IN ('payments', 'wallets', 'wallet_transactions');
   ```

2. **Check user_id Column Exists:**
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name IN ('payments', 'wallets') 
   AND column_name = 'user_id';
   ```

3. **Check RLS is Enabled:**
   ```sql
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE tablename IN ('payments', 'wallets', 'wallet_transactions');
   ```
   Should show `rowsecurity = t` (true)

4. **Check Policies Exist:**
   ```sql
   SELECT tablename, policyname 
   FROM pg_policies 
   WHERE tablename IN ('payments', 'wallets', 'wallet_transactions');
   ```
   Should show multiple policies

5. **Check Functions Exist:**
   ```sql
   SELECT routine_name 
   FROM information_schema.routines 
   WHERE routine_name IN ('update_wallet_balance', 'get_wallet_balance');
   ```

## 🧪 Test It Works

After the script runs successfully:

1. **Run the Flutter app**
2. **Go to Wallet screen**
3. **Click "Top Up KSh 100"**
4. **Check Supabase:**
   - Go to Table Editor → `wallets`
   - You should see a new row with your balance

## 🚨 If You Still Get Errors

### Error: "relation already exists"
This is OK! It means the tables were already created. The script will skip them.

### Error: "permission denied"
Your Supabase user might not have admin privileges. Try:
1. Go to Settings → Database
2. Make sure you're using the service role key (not anon key)
3. Re-run the script

### Error: "function already exists"
This is OK! The script drops old functions before creating new ones.

### Error: "cannot create UNIQUE constraint"
This means you have duplicate `user_id` values in your tables.

**Fix:**
```sql
-- Delete duplicates (keeping newest)
DELETE FROM wallets a
USING wallets b
WHERE a.id < b.id
AND a.user_id = b.user_id;

-- Then re-run the main script
```

## 📞 Still Need Help?

1. Run `check_table_schemas.sql` to see your actual table structure
2. Copy the output
3. Share it so we can debug further

## ✅ Success Indicators

You'll know it worked when:
- ✅ No errors in SQL Editor
- ✅ You see: "✅ All tables, policies, and functions created successfully!"
- ✅ Wallet screen loads without errors
- ✅ Top up button works
- ✅ Balance persists after closing app
- ✅ Data appears in Supabase Table Editor
