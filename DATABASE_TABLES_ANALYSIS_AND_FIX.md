# Database Tables Analysis and Fix

## Issue Summary
The following tables exist in Supabase but cannot store data:
- `deliveries`
- `delivery_updates`
- `payments`
- `wallet_transactions`
- `wallets`

## Root Cause Analysis

### 1. **Tables Are Not Being Used by the Application**

#### Deliveries & Delivery Updates
- **Current Implementation**: Uses `cargo_requests` table instead
- **Location**: `lib/providers/delivery_providers.dart`
- **Code**: Lines 323-327, 402-406
```dart
// Currently using cargo_requests table
final response = await supabase
    .from('cargo_requests')
    .insert(cargoRequestData)
```
- **Problem**: The app never writes to `deliveries` or `delivery_updates` tables

#### Payments
- **Current Implementation**: Uses in-memory storage only (no database)
- **Location**: `lib/screens/payment_screen.dart` lines 60-69
```dart
final newPayment = PaymentRecord(...);
final list = [...ref.read(paymentsProvider)];
list.insert(0, newPayment);
ref.read(paymentsProvider.notifier).state = list; // Only in-memory
```
- **Problem**: Payments are stored in app state, not in database

#### Wallets & Wallet Transactions
- **Current Implementation**: Uses in-memory service only
- **Location**: `lib/services/wallet_service.dart`
```dart
class WalletService {
  double _balance = 0; // In-memory only
  final List<Map<String, dynamic>> _ledger = []; // In-memory only
}
```
- **Problem**: Wallet data is lost when app closes

### 2. **Possible RLS (Row Level Security) Issues**
Even if the app tried to write to these tables, RLS policies might be blocking inserts.

## Solution

### Option 1: Use Existing Tables (Recommended for MVP)
**Current tables that ARE working:**
- ✅ `cargo_requests` - for deliveries
- ✅ `rides` - for ride payments
- ✅ App state - for temporary payment records

**Actions Required:**
1. Keep using `cargo_requests` for deliveries
2. Update payment flow to store in `rides` table
3. No changes needed for wallet (in-memory is fine for MVP)

### Option 2: Fix and Use New Tables (For Production)

#### Step 1: Enable RLS Policies
Run these SQL commands in Supabase SQL Editor:

```sql
-- Enable RLS on all tables
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- Deliveries policies
CREATE POLICY "Users can view their own deliveries"
  ON deliveries FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own deliveries"
  ON deliveries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own deliveries"
  ON deliveries FOR UPDATE
  USING (auth.uid() = user_id);

-- Delivery Updates policies
CREATE POLICY "Users can view delivery updates for their deliveries"
  ON delivery_updates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM deliveries
      WHERE deliveries.id = delivery_updates.delivery_id
      AND deliveries.user_id = auth.uid()
    )
  );

CREATE POLICY "System can insert delivery updates"
  ON delivery_updates FOR INSERT
  WITH CHECK (true);

-- Payments policies
CREATE POLICY "Users can view their own payments"
  ON payments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own payments"
  ON payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

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
```

#### Step 2: Update Application Code

**For Deliveries:**
```dart
// In lib/providers/delivery_providers.dart
// Replace cargo_requests with deliveries table

// Current (line 323):
final response = await supabase.from('cargo_requests')

// Change to:
final response = await supabase.from('deliveries')
```

**For Payments:**
```dart
// In lib/screens/payment_screen.dart (around line 60)
// Add database insert after creating PaymentRecord

final newPayment = PaymentRecord(...);

// Add this - save to database:
await supabase.from('payments').insert({
  'user_id': supabase.auth.currentUser!.id,
  'ride_id': widget.rideId,
  'amount': fare,
  'method': _method,
  'status': 'completed',
  'created_at': DateTime.now().toIso8601String(),
});

// Then update local state:
final list = [...ref.read(paymentsProvider)];
list.insert(0, newPayment);
ref.read(paymentsProvider.notifier).state = list;
```

**For Wallet:**
```dart
// In lib/services/wallet_service.dart
// Replace in-memory storage with Supabase

import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  final _supabase = Supabase.instance.client;
  
  Future<double> get balance async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    
    final response = await _supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    
    return response?['balance']?.toDouble() ?? 0;
  }
  
  Future<void> topUp(double amount) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Update wallet balance
    await _supabase.rpc('update_wallet_balance', {
      'user_id': userId,
      'amount': amount
    });
    
    // Log transaction
    await _supabase.from('wallet_transactions').insert({
      'wallet_id': userId, // assuming wallet_id = user_id
      'type': 'credit',
      'amount': amount,
      'description': 'Wallet top-up',
    });
  }
  
  // Similar for charge() and refund()
}
```

#### Step 3: Create Database Function for Wallet
```sql
-- In Supabase SQL Editor
CREATE OR REPLACE FUNCTION update_wallet_balance(
  user_id UUID,
  amount NUMERIC
)
RETURNS void AS $$
BEGIN
  -- Insert wallet if doesn't exist
  INSERT INTO wallets (user_id, balance, created_at, updated_at)
  VALUES (user_id, amount, NOW(), NOW())
  ON CONFLICT (user_id) 
  DO UPDATE SET 
    balance = wallets.balance + amount,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Testing Checklist

After implementing fixes, test:

### Deliveries
- [ ] Create a new delivery booking
- [ ] Check if record appears in `deliveries` table
- [ ] Verify delivery updates are logged in `delivery_updates` table

### Payments
- [ ] Complete a ride payment
- [ ] Check if record appears in `payments` table
- [ ] Verify payment method and amount are correct

### Wallet
- [ ] Top up wallet
- [ ] Check if `wallets` table shows new balance
- [ ] Check if `wallet_transactions` table logs the transaction
- [ ] Close and reopen app - verify balance persists

## Current Table Usage Summary

| Table | Currently Used? | Storage Method | Needs Fix? |
|-------|----------------|----------------|------------|
| `deliveries` | ❌ No | Uses `cargo_requests` instead | Optional |
| `delivery_updates` | ❌ No | Not implemented | Optional |
| `payments` | ❌ No | In-memory only | Yes (for production) |
| `wallet_transactions` | ❌ No | In-memory only | Yes (for production) |
| `wallets` | ❌ No | In-memory only | Yes (for production) |
| `cargo_requests` | ✅ Yes | Supabase | Working |
| `rides` | ✅ Yes | Supabase | Working |

## Recommendation

**For immediate fix (MVP):**
1. Keep using existing implementation
2. Document that deliveries use `cargo_requests`
3. Add payments to `rides` table instead of separate table

**For production:**
1. Implement Option 2 Step-by-Step
2. Migrate existing data
3. Update all references in code
4. Add proper error handling

## Files to Modify

If implementing Option 2:
- ✏️ `lib/providers/delivery_providers.dart` (lines 323, 402)
- ✏️ `lib/screens/payment_screen.dart` (lines 60-69)
- ✏️ `lib/services/wallet_service.dart` (entire file)
- ✏️ `lib/repositories/wallet_repository.dart` (update to use async methods)
- ✏️ `lib/providers/payments_providers.dart` (update to use async)

## Next Steps

1. **Decide**: Option 1 (keep current) or Option 2 (fix tables)?
2. **If Option 2**: Run SQL scripts first in Supabase
3. **Then**: Update Flutter code files listed above
4. **Finally**: Test using checklist above
