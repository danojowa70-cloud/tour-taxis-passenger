# 📱 Twilio SMS Setup Guide

## 🔑 Your Twilio Credentials

**Account SID**: `AC87248ccf5627d839bccb19564a808fb`  
**Auth Token**: You need to get this from Twilio Console  
**Phone Number**: You need to get a Twilio phone number

---

## 📋 Step 1: Get Your Auth Token and Phone Number

1. **Go to Twilio Console**: https://console.twilio.com/
2. **Login** with your account
3. **Find Auth Token**:
   - On the dashboard, you'll see "Account Info"
   - Copy the **Auth Token** (click the eye icon to reveal it)
4. **Get a Phone Number**:
   - Go to Phone Numbers → Manage → Active Numbers
   - If you don't have one, click "Buy a number"
   - Select a number with SMS capability
   - Copy the number (format: +1234567890)

---

## ⚙️ Step 2: Configure the App

### Option A: Direct Configuration (For Testing Only - NOT SECURE for Production)

Edit `lib/services/twilio_sms_service.dart`:

```dart
static const String _authToken = 'YOUR_AUTH_TOKEN_FROM_TWILIO';
static const String _twilioPhoneNumber = '+1234567890'; // Your Twilio number
```

### Option B: Secure Configuration (Recommended for Production)

Create a file: `lib/config/twilio_config.dart`

```dart
class TwilioConfig {
  // These should come from environment variables or secure storage
  static String get authToken => const String.fromEnvironment(
    'TWILIO_AUTH_TOKEN',
    defaultValue: 'YOUR_AUTH_TOKEN_HERE',
  );
  
  static String get phoneNumber => const String.fromEnvironment(
    'TWILIO_PHONE_NUMBER',
    defaultValue: '+1234567890',
  );
}
```

Then run with:
```bash
flutter run --dart-define=TWILIO_AUTH_TOKEN=your_token --dart-define=TWILIO_PHONE_NUMBER=+1234567890
```

---

## 🧪 Step 3: Test SMS Functionality

### Test 1: Simple SMS Test

```dart
import 'package:tour_taxis/services/twilio_sms_service.dart';

// Send a test SMS
await TwilioSmsService.sendSms(
  toPhoneNumber: '+254712345678', // Replace with your phone
  message: 'Test SMS from TourTaxi!',
);
```

### Test 2: Booking Confirmation

```dart
await TwilioSmsService.sendBookingConfirmation(
  phoneNumber: '+254712345678',
  bookingId: 'TT12345',
  vehicleType: 'Sedan',
  pickupLocation: 'Nairobi CBD',
  dropoffLocation: 'Jomo Kenyatta Airport',
);
```

### Test 3: OTP

```dart
await TwilioSmsService.sendOtp(
  phoneNumber: '+254712345678',
  otp: '123456',
);
```

---

## 🔌 Step 4: Integrate into Your App

### Send SMS when Booking is Created

Edit `lib/providers/boarding_pass_providers.dart` - in the `createBoardingPass` method:

```dart
// After successfully creating boarding pass
if (boardingPass != null) {
  // Get user phone number
  final userProfile = ref.read(userProfileProvider).asData?.value;
  final phoneNumber = userProfile?['phone'] as String?;
  
  if (phoneNumber != null) {
    // Send SMS confirmation
    TwilioSmsService.sendPremiumBookingConfirmation(
      phoneNumber: phoneNumber,
      bookingId: boardingPass.bookingId,
      vehicleType: boardingPass.vehicleTypeDisplayName,
      origin: boardingPass.origin ?? '',
      destination: boardingPass.destination,
      departureTime: _formatDateTime(boardingPass.departureTime),
    );
  }
}
```

### Send SMS when Ride Starts

Edit your ride management code:

```dart
// When ride starts
await TwilioSmsService.sendRideStartedNotification(
  phoneNumber: passengerPhone,
  destination: destinationAddress,
);
```

### Send SMS when Driver Arrives

```dart
// When driver arrives at pickup
await TwilioSmsService.sendDriverArrivalNotification(
  phoneNumber: passengerPhone,
  driverName: driverName,
  vehicleNumber: vehicleRegistration,
);
```

---

## 📊 SMS Templates Available

| Method | Use Case |
|--------|----------|
| `sendSms()` | Generic SMS |
| `sendBookingConfirmation()` | Regular taxi booking |
| `sendOtp()` | OTP verification |
| `sendDriverArrivalNotification()` | Driver arrived at pickup |
| `sendRideStartedNotification()` | Ride has started |
| `sendRideCompletedNotification()` | Ride completed |
| `sendPremiumBookingConfirmation()` | Premium booking (helicopter/jet) |

---

## 🚨 Important Notes

### ⚠️ Security Warning
**NEVER** commit your Auth Token to Git! Add it to `.gitignore`:

```
# .gitignore
lib/config/twilio_config.dart
*.env
```

### 💰 Cost
- Twilio charges per SMS sent
- Check pricing at: https://www.twilio.com/sms/pricing
- Kenya SMS: ~$0.04 per message

### 📱 Phone Number Format
Always use E.164 format:
- ✅ Correct: `+254712345678`
- ❌ Wrong: `0712345678`
- ❌ Wrong: `254712345678`

### 🔍 Testing
Use Twilio's test credentials for development:
- Test Account SID: `AC...` (you have this)
- Test Phone Numbers don't send real SMS
- Upgrade to paid account for production

---

## 🐛 Troubleshooting

### Error: "The 'From' number +1234... is not a valid phone number"
**Fix**: Update `_twilioPhoneNumber` with your actual Twilio number

### Error: "Authenticate"
**Fix**: Check your Auth Token is correct

### Error: "Permission to send an SMS has not been enabled"
**Fix**: 
1. Go to Twilio Console → Phone Numbers
2. Select your number
3. Enable SMS capability

### SMS not received
**Check**:
1. Phone number is in E.164 format (+254...)
2. You have SMS credits in Twilio
3. Check Twilio logs in console for delivery status
4. Check phone number is verified (for trial accounts)

---

## 🔄 Alternative: Use Supabase Edge Function (More Secure)

Instead of calling Twilio from the app, create a Supabase Edge Function:

```typescript
// supabase/functions/send-sms/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { to, message } = await req.json()
  
  const twilioSid = Deno.env.get('TWILIO_ACCOUNT_SID')
  const twilioToken = Deno.env.get('TWILIO_AUTH_TOKEN')
  const twilioPhone = Deno.env.get('TWILIO_PHONE_NUMBER')
  
  const auth = btoa(`${twilioSid}:${twilioToken}`)
  
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        From: twilioPhone!,
        To: to,
        Body: message,
      }),
    }
  )
  
  return new Response(JSON.stringify({ success: true }))
})
```

Then call from Flutter:
```dart
await Supabase.instance.client.functions.invoke(
  'send-sms',
  body: {'to': '+254712345678', 'message': 'Hello!'},
);
```

This is **much more secure** as credentials stay on the server!

---

## ✅ Quick Start Checklist

- [ ] Get Auth Token from Twilio Console
- [ ] Get Twilio Phone Number
- [ ] Update `twilio_sms_service.dart` with credentials
- [ ] Test with your phone number
- [ ] Integrate into booking flow
- [ ] Test end-to-end
- [ ] Consider moving to backend for security
- [ ] Add proper error handling
- [ ] Monitor Twilio usage and costs

---

Need help? Check Twilio docs: https://www.twilio.com/docs/sms
