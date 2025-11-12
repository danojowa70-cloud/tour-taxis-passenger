# 📱 SMS Quick Start Guide

## ✅ What's Been Created

1. **Twilio SMS Service** (`lib/services/twilio_sms_service.dart`)
   - Send generic SMS
   - Pre-built templates for bookings, OTP, notifications
   
2. **SMS Test Screen** (`lib/screens/sms_test_screen.dart`)
   - Easy testing interface
   - Test all SMS templates

3. **Setup Guide** (`TWILIO_SMS_SETUP.md`)
   - Detailed configuration instructions
   - Troubleshooting help

---

## 🚀 Quick Setup (5 Minutes)

### Step 1: Get Twilio Credentials

1. Go to: https://console.twilio.com/
2. Login with your account
3. Copy **Auth Token** from dashboard
4. Get a **Phone Number** from Phone Numbers → Manage → Buy a Number

### Step 2: Configure

Edit `lib/services/twilio_sms_service.dart`:

```dart
static const String _authToken = 'YOUR_AUTH_TOKEN';  // ← Add your token here
static const String _twilioPhoneNumber = '+1234567890';  // ← Add your Twilio number
```

### Step 3: Test

Add this to your app's navigation or create a button:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const SmsTestScreen()),
);
```

Then test SMS sending!

---

## 📞 Your Twilio Info

- **Account SID**: `AC87248ccf5627d839bccb19564a808fb`
- **Auth Token**: Get from Twilio Console
- **Phone Number**: Get from Twilio Console

---

## 💡 Usage Examples

### Send Booking Confirmation
```dart
await TwilioSmsService.sendBookingConfirmation(
  phoneNumber: '+254712345678',
  bookingId: 'TT12345',
  vehicleType: 'Sedan',
  pickupLocation: 'Nairobi CBD',
  dropoffLocation: 'Airport',
);
```

### Send OTP
```dart
await TwilioSmsService.sendOtp(
  phoneNumber: '+254712345678',
  otp: '123456',
);
```

### Send Premium Booking
```dart
await TwilioSmsService.sendPremiumBookingConfirmation(
  phoneNumber: '+254712345678',
  bookingId: 'BP12345',
  vehicleType: 'Helicopter',
  origin: 'Nairobi',
  destination: 'Mombasa',
  departureTime: 'Tomorrow 10:00 AM',
);
```

---

## ⚠️ Important

1. **Phone Format**: Always use +254... (E.164 format)
2. **Security**: Don't commit Auth Token to Git!
3. **Cost**: Each SMS costs money (~$0.04)
4. **Trial Account**: Can only send to verified numbers

---

## 🐛 Troubleshooting

- **"Auth Token not configured"** → Update `_authToken` in service file
- **"Phone number not configured"** → Update `_twilioPhoneNumber` in service file
- **SMS not received** → Check phone number format (+254...)
- **"Permission denied"** → Enable SMS on your Twilio number

---

## 📖 Full Documentation

See `TWILIO_SMS_SETUP.md` for complete setup instructions and all features!
