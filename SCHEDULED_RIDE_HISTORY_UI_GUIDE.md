# Scheduled Ride History - Visual UI Guide

## UI States Comparison

### Active Ride Card (Clickable)
```
┌────────────────────────────────────────┐
│  Westlands, Nairobi          [CONFIRMED]│ ← Status badge (purple)
│  Nairobi, Kenya                        │
├────────────────────────────────────────┤
│  📅 Jan 11, 2025 - 10:30 AM           │
│                                         │
│  🔐 OTP to Share with Driver           │
│  │  619811            📋 Copy          │ ← OTP section
│                                         │
│  ℹ️  Booked on Jan 08, 2025            │
└────────────────────────────────────────┘
        ↑ Full opacity, clickable
```

### Completed Ride Card (Non-clickable)
```
┌────────────────────────────────────────┐
│  ~~Westlands, Nairobi~~     [COMPLETED]│ ← Strikethrough text
│  ~~Nairobi, Kenya~~              ↑     │   Green badge
├────────────────────────────────────────┤
│  📅 Jan 11, 2025 - 10:30 AM           │
│                                         │
│  🔐 OTP Given to Driver                │
│  │  619811            📋 Copy          │
│                                         │
│  👤 Driver Details                     │
│     👤 John Doe                        │
│     📞 +254 712 345 678                │
│     🚗 KAA 123A                        │
│                                         │
│  ℹ️  Booked on Jan 08, 2025            │
│                                         │
│ ┌──────────────────────────────────┐  │
│ │ ✅ This ride has been completed. │  │ ← Completion banner
│ │    Check your receipts for       │  │   (Green background)
│ │    details.                      │  │
│ └──────────────────────────────────┘  │
└────────────────────────────────────────┘
    ↑ 70% opacity, non-clickable
```

### Cancelled Ride Card (Non-clickable)
```
┌────────────────────────────────────────┐
│  ~~Westlands, Nairobi~~     [CANCELLED]│ ← Strikethrough text
│  ~~Nairobi, Kenya~~              ↑     │   Red badge
├────────────────────────────────────────┤
│  📅 Jan 11, 2025 - 10:30 AM           │
│                                         │
│  ℹ️  Booked on Jan 08, 2025            │
│                                         │
│ ┌──────────────────────────────────┐  │
│ │ ❌ This ride was cancelled.      │  │ ← Cancellation banner
│ └──────────────────────────────────┘  │   (Orange background)
└────────────────────────────────────────┘
    ↑ 70% opacity, non-clickable
```

## Status Badge Colors

| Status        | Badge Color | Text Color | Background      |
|---------------|-------------|------------|-----------------|
| PENDING       | Grey        | Grey       | Grey light      |
| CONFIRMED     | Purple      | Purple     | Purple light    |
| IN_PROGRESS   | Blue        | Blue       | Blue light      |
| COMPLETED     | Green       | Green      | Green light     |
| CANCELLED     | Red         | Red        | Red light       |

## Interaction Behaviors

### When Tapping Active Ride
```
User Taps → Navigate to Scheduled Ride Details Screen
            ↓
         Full ride tracking view with map
```

### When Tapping Completed Ride
```
User Taps → SnackBar appears
            ↓
         ┌─────────────────────────────────┐
         │ 🎯 This ride has been completed.│
         │    Check your receipts for      │
         │    details.                     │
         └─────────────────────────────────┘
         (Green background, 2 seconds)
```

### When Tapping Cancelled Ride
```
User Taps → SnackBar appears
            ↓
         ┌─────────────────────────────────┐
         │ ⚠️  This ride was cancelled.    │
         └─────────────────────────────────┘
         (Orange background, 2 seconds)
```

## Visual Indicators Summary

### Completed Rides
✅ **Opacity**: 70% (faded appearance)  
✅ **Text**: Strikethrough on location names  
✅ **Badge**: Green "COMPLETED"  
✅ **Banner**: Green with checkmark icon  
✅ **Message**: "Check your receipts for details"  
✅ **Clickable**: No  

### Cancelled Rides
❌ **Opacity**: 70% (faded appearance)  
❌ **Text**: Strikethrough on location names  
❌ **Badge**: Red "CANCELLED"  
❌ **Banner**: Orange with cancel icon  
❌ **Message**: "This ride was cancelled"  
❌ **Clickable**: No  

### Active Rides (Pending/Confirmed/In Progress)
🚗 **Opacity**: 100% (full brightness)  
🚗 **Text**: Normal (no strikethrough)  
🚗 **Badge**: Status-dependent color  
🚗 **OTP**: Prominently displayed  
🚗 **Clickable**: Yes  

## Icon Legend

| Icon | Meaning                    |
|------|----------------------------|
| ✅   | Check mark (completed)     |
| ❌   | Cancel (cancelled)         |
| 🔐   | OTP security indicator     |
| 📅   | Calendar (date/time)       |
| 👤   | Person (driver/passenger)  |
| 📞   | Phone number               |
| 🚗   | Vehicle                    |
| ℹ️   | Information                |
| 📋   | Copy to clipboard          |

## Animation & Transitions

### Real-time Status Update
```
Status Changes (via Realtime) → UI Updates Instantly
                                 ↓
                     Fade animation (0.3s)
                     + Status badge color change
                     + Opacity change
                     + Strikethrough appears
```

### Tap Feedback
```
User Taps Non-clickable Card → Brief highlight (0.1s)
                                ↓
                         SnackBar slides up (0.3s)
```

## Responsive Design

The UI adapts to different screen sizes:

- **Small screens**: Single column layout, compact spacing
- **Medium screens**: Comfortable padding, readable text
- **Large screens**: Maximum width constraint, centered content

All touch targets meet minimum size requirements (48x48 dp) for accessibility.

## Dark Mode Support

The UI automatically adapts to dark mode:

- Status badges maintain contrast ratios
- Background colors are inverted appropriately
- Text remains readable in all states
- Icons maintain visibility

## Accessibility Features

1. **Screen Reader Support**: All status changes announced
2. **High Contrast**: Color + text + icons (not color-only)
3. **Large Touch Targets**: Easy to tap even for users with motor difficulties
4. **Clear Labels**: Descriptive text for all elements
5. **Status Announcements**: Changes are communicated clearly

## Example User Flow

### Scenario: Ride Completion

1. **Driver completes ride** → Backend updates status to "completed"
2. **Real-time sync** → Passenger app receives update
3. **UI updates instantly**:
   - Card fades to 70% opacity
   - Location text shows strikethrough
   - Status badge changes to green "COMPLETED"
   - Completion banner appears
   - Card becomes non-clickable
4. **User sees changes** → Understands ride is done
5. **User taps card** → Gets helpful message directing to receipts
6. **User checks receipts** → Finds detailed ride information

## Developer Notes

### Key CSS/Styling Properties
- `opacity: 0.7` for completed/cancelled
- `TextDecoration.lineThrough` for locations
- `BorderRadius: 12` for cards
- `Padding: 16` for card content
- `Margin: 12` between cards

### State Variables Used
```dart
final isCompleted = status == 'completed';
final isCancelled = status == 'cancelled';
final isClickable = !isCompleted && !isCancelled;
```

### Conditional Rendering
```dart
// Opacity wrapper
Opacity(opacity: (isCompleted || isCancelled) ? 0.7 : 1.0)

// Gesture detection
GestureDetector(onTap: isClickable ? onTap : null)

// Completion banner
if (isCompleted || isCancelled) ...[ banner widget ]
```
