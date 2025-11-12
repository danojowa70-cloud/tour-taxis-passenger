# Vehicle Selection Persistence Fix

## Problem

When a user selected a vehicle type (e.g., SUV) on the home screen and clicked "Book SUV", the confirm ride screen would default back to "Sedan" instead of keeping the SUV selection.

## Root Cause

The selected vehicle type from the home screen was not being passed to the confirm ride screen. The `_selectedVehicle` state variable in the confirm screen was always initialized to `'car'` (Sedan) regardless of what was selected on the home screen.

## Solution

### 1. Updated RideFlowState Provider

Added `vehicleType` field to store the selected vehicle across screens:

**File: `lib/providers/ride_flow_providers.dart`**

```dart
class RideFlowState {
  // ... existing fields
  final String? vehicleType; // Selected vehicle type from home screen
  
  const RideFlowState({
    // ... existing params
    this.vehicleType
  });
}
```

### 2. Save Selection in Home Screen

Updated `_navigateToConfirmScreen()` to save the selected vehicle to the provider before navigation:

**File: `lib/screens/home_screen.dart`**

```dart
void _navigateToConfirmScreen() async {
  // Ensure route data is calculated before navigating
  if (_pickupLocation != null && _destinationLocation != null) {
    await _calculateRouteData();
  }
  
  // Save selected vehicle to provider
  if (_selectedVehicle.isNotEmpty) {
    ref.read(rideFlowProvider.notifier).updateFrom(
      vehicleType: _selectedVehicle,
    );
  }
  
  if (mounted) {
    Navigator.of(context).pushNamed('/confirm');
  }
}
```

### 3. Read Selection in Confirm Screen

Added `initState()` to read the vehicle type from provider and update the local state:

**File: `lib/screens/confirm_ride_screen.dart`**

```dart
@override
void initState() {
  super.initState();