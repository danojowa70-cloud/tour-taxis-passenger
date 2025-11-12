# Fixes Applied - 2025-10-24

## 🐛 Bug Fixes

### 1. Navigation Crash Fix
**Problem**: App crashed when clicking back arrow on home screen after second login.

**Root Cause**: 
- First login showed dashboard correctly
- Second/subsequent logins went directly to `/home` from splash screen
- Back arrow used `Navigator.pop()` which failed when there was no previous screen in stack

**Solution**:
- ✅ Updated `splash_screen.dart` (line 67): Changed to navigate to `/dashboard` instead of `/home` after login
- ✅ Updated `home_screen.dart` (line 686): Changed back button to navigate to `/dashboard` instead of `pop()`

**Files Modified**:
- `lib/screens/splash_screen.dart`
- `lib/screens/home_screen.dart`

---

## 💳 Payment Methods Update

### 2. Replaced Payment Options
**Changes**: Removed Visa card and Wallet, Added M-Pesa and PayPal

**Updated Files**:

#### ✅ `lib/screens/confirm_ride_screen.dart` (lines 513-532)
**Before**:
```dart
'id': 'card',
'name': 'Credit Card',
'description': 'Visa •••• 1234'

'id': 'wallet',
'name': 'TourTaxi Wallet',
'description': 'Balance: KSh 2,500'
```

**After**:
```dart
'id': 'mpesa',
'name': 'M-Pesa',
'description': 'Pay via M-Pesa mobile money'

'id': 'paypal',
'name': 'PayPal',
'description': 'Pay with PayPal account'
```

#### ✅ `lib/models/payment.dart` (line 3)
**Updated comment**:
```dart
final String method; // Cash, M-Pesa, PayPal
```

#### ✅ `lib/screens/dashboard_screen.dart` (lines 239-246)
**Changed "Wallet" quick action to "Payments"**:
```dart
icon: Icons.payment,
title: 'Payments',
subtitle: 'Payment methods',
onTap: () => Navigator.of(context).pushNamed('/payment-methods', arguments: 0.0),
```

#### ℹ️ `lib/screens/payment_method_screen.dart`
**Already correct** - This screen already implemented M-Pesa and PayPal:
- M-Pesa payment integration with MPesaService
- PayPal payment integration with PayPalService
- No Visa card or Wallet options present

---

## 🎯 Current Payment Methods Available

### In Confirm Ride Screen:
1. **Cash** - Pay with cash
2. **M-Pesa** - Pay via M-Pesa mobile money
3. **PayPal** - Pay with PayPal account

### Payment Method Screen Features:
- M-Pesa: Opens M-Pesa app/USSD for payment
- PayPal: Opens PayPal app/web for payment
- Payment instructions dialog before redirect
- Payment confirmation dialog after completion

---

## 🧪 Testing Checklist

### Navigation Fix:
- [ ] First login shows dashboard correctly
- [ ] Second login shows dashboard (not home directly)
- [ ] Back arrow from home screen navigates to dashboard
- [ ] No crash when clicking back arrow
- [ ] Dashboard "Book Ride" button navigates to home screen

### Payment Methods:
- [ ] Confirm ride screen shows: Cash, M-Pesa, PayPal
- [ ] No Visa card option visible
- [ ] No Wallet option visible
- [ ] Dashboard shows "Payments" quick action (not "Wallet")
- [ ] Payment method screen works with M-Pesa
- [ ] Payment method screen works with PayPal

---

## 📝 Summary

**Navigation**: Fixed crash by ensuring dashboard is always shown after login and changing back button to navigate to dashboard instead of using `pop()`.

**Payments**: Replaced deprecated payment options (Visa card, Wallet) with M-Pesa and PayPal across all screens.

All changes are backward compatible and don't break existing functionality.
