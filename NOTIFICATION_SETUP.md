# Scheduled Ride Notifications Setup

## 📦 Required Dependencies

Add these to your `pubspec.yaml` files:

### For Passenger App (tour_taxis/pubspec.yaml)
```yaml
dependencies:
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.2
```

### For Driver App (tour_taxi_driver/pubspec.yaml)
```yaml
dependencies:
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.2
```

## 🔧 Installation Steps

### 1. Install Dependencies
```bash
# Passenger app
cd C:\Users\vansh\StudioProjects\tour_taxis
flutter pub get

# Driver app
cd C:\Users\vansh\StudioProjects\tour_taxi_driver
flutter pub get
```

### 2. Android Configuration

Add to `android/app/src/main/AndroidManifest.xml` (both apps):

```xml
<!-- Inside <manifest> tag, before <application> -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- Inside <application> tag -->
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

## 📱 How It Works

### Passenger Features:
1. **When Ride is Scheduled**:
   - ✅ Reminder notification 30 mins before ride
   - ✅ Notification at ride time

2. **When Driver Accepts**:
   - ✅ Instant notification "Driver Accepted Your Ride!"
   - ✅ Shows driver confirmation

3. **When Driver Cancels**:
   - ✅ Instant notification "Driver Cancelled"
   - ✅ Alert to book another driver

### Driver Features:
1. **When New Ride is Scheduled**:
   - ✅ Instant popup notification
   - ✅ Shows destination, fare, and time
   - ✅ Tap to view in Scheduled Rides screen

2. **When Driver Accepts a Ride**:
   - ✅ Reminder notification 30 mins before
   - ✅ Notification at exact ride time
   - ✅ "Time to Start Your Ride!" alert

3. **Real-time Updates**:
   - ✅ Live updates via Supabase Realtime
   - ✅ Notifications work even when app is in background

## 🔔 Notification Types

| Type | When | Recipients | Priority |
|------|------|------------|----------|
| New Scheduled Ride | Passenger schedules | All drivers | High |
| Driver Accepted | Driver accepts | Passenger | High |
| Driver Cancelled | Driver cancels | Passenger | High |
| Ride Reminder | 30 mins before | Both | High |
| Ride Starting | At scheduled time | Driver | Max |

## ⚙️ Customization

### Change Reminder Time
In both services, modify the `minutesBefore` parameter:

```dart
// Default is 30 minutes
await ScheduledRideNotificationsService.scheduleRideReminder(
  // ...
  minutesBefore: 60, // Change to 60 minutes
);
```

### Notification Channels
- **scheduled_rides**: Ride status updates
- **ride_reminders**: Time-based reminders
- **new_scheduled_rides**: New ride alerts (driver only)
- **ride_start**: Exact start time notifications

## 🧪 Testing

1. **Test Immediate Notifications**:
```dart
await ScheduledRideNotificationsService.showTestNotification();
```

2. **Test Scheduled Notifications**:
   - Schedule a ride for 5 minutes from now
   - Change `minutesBefore` to 3
   - Should get notification in 2 minutes

3. **Test Real-time Updates**:
   - Passenger schedules ride
   - Driver should get immediate popup
   - Driver accepts
   - Passenger should get immediate confirmation

## 🐛 Troubleshooting

### Notifications not showing?
1. Check Android permissions are granted
2. Ensure app has notification permissions
3. Check Android battery optimization settings
4. Verify Supabase Realtime is working

### Scheduled notifications not firing?
1. Android: Check exact alarm permissions
2. Ensure device is not in power saving mode
3. Check timezone initialization

### Real-time updates not working?
1. Verify Supabase Realtime is enabled
2. Check RLS policies allow SELECT on scheduled_rides
3. Ensure user is authenticated

## ✅ Verification Checklist

- [ ] Dependencies added to both apps
- [ ] Android permissions added
- [ ] Passenger app initializes notifications
- [ ] Driver app initializes notifications
- [ ] Passenger gets notification when driver accepts
- [ ] Driver gets notification for new scheduled rides
- [ ] Both get reminders before ride time
- [ ] Driver gets notification at exact ride time
