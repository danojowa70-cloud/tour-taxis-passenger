# Unified Backend Updates - Driver Ride Acceptance

This document lists all the changes made to the unified backend for the driver ride acceptance feature.

## Files Modified

### 1. `tourtaxi-unified-backend/src/services/rides.service.ts`

**Added:** `acceptRide` method (lines 112-189)

```typescript
async acceptRide(rideId: string, driverId: string): Promise<{
  success: boolean;
  message?: string;
  ride?: any;
  driver?: any;
}>
```

**Functionality:**
- Validates driver exists and is available
- Updates ride status to 'accepted'
- Assigns driver to ride
- Creates `ride:accepted` event with complete driver data
- Updates driver availability to false
- Returns success/failure response

---

### 2. `tourtaxi-unified-backend/src/controllers/rides.controller.ts`

**Added:** `acceptRide` controller function (lines 62-86)

```typescript
export async function acceptRide(req: Request, res: Response)
```

**Functionality:**
- Validates request parameters (rideId, driverId)
- Calls RidesService.acceptRide()
- Returns HTTP response with ride and driver data

---

### 3. `tourtaxi-unified-backend/src/server.ts`

**Added:** Import statement (line 14)
```typescript
import { RidesService } from './services/rides.service';
```

**Added:** Accept ride endpoint (lines 226-251)
```typescript
app.post('/api/rides/:rideId/accept', async (req, res) => { ... })
```

**Endpoint:** `POST /api/rides/:rideId/accept`

**Request Body:**
```json
{
  "driverId": "driver-uuid-here"
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Ride accepted successfully",
  "ride": { /* ride data */ },
  "driver": { /* driver data */ }
}
```

**Error Response:**
```json
{
  "error": "Driver not found" | "Driver is not available" | "Failed to update ride"
}
```

---

## How to Test

### 1. Restart the Unified Backend Server

```powershell
cd tourtaxi-unified-backend
npm run dev
```

### 2. Test the Endpoint

Using curl or Postman:

```bash
curl -X POST http://localhost:3000/api/rides/:rideId/accept \
  -H "Content-Type: application/json" \
  -d '{
    "driverId": "your-driver-uuid"
  }'
```

### 3. Verify in Database

Check the following tables:
- `rides` - status should be 'accepted', driver_id should be set
- `ride_events` - should have new event with type 'ride:accepted'
- `drivers` - is_available should be false for the accepting driver

---

## Integration with Flutter App

The Flutter app already has the service method to call this endpoint, but it primarily uses Supabase client directly. Both methods work:

### Method 1: Direct Supabase (Recommended)
```dart
final rideService = RideService(Supabase.instance.client);
await rideService.acceptRide(rideId: rideId, driverId: driverId);
```

### Method 2: REST API
```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/rides/$rideId/accept'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'driverId': driverId}),
);
```

---

## Real-time Updates

When a driver accepts a ride, the passenger app receives updates via:

1. **Supabase Realtime** - listening to `ride_events` table
2. **Socket.IO** (if using the Socket.IO implementation)

The passenger app automatically receives:
- Driver name
- Driver phone
- Vehicle information
- Driver rating
- Vehicle make/model/plate

---

## Database Schema Requirements

Ensure your database has these columns:

### `rides` table:
- `driver_id` (uuid, nullable)
- `status` (text)
- `accepted_at` (timestamp, nullable)

### `drivers` table:
- `id` (uuid, primary key)
- `name` (text)
- `phone` (text)
- `vehicle_make` (text)
- `vehicle_model` (text)
- `vehicle_type` (text)
- `vehicle_number` (text)
- `vehicle_plate` (text)
- `rating` (numeric)
- `is_online` (boolean)
- `is_available` (boolean)

### `ride_events` table:
- `id` (uuid, primary key)
- `ride_id` (uuid)
- `actor` (text)
- `event_type` (text)
- `payload` (jsonb)
- `created_at` (timestamp)

---

## Security Considerations

The current implementation does basic validation. For production, consider adding:

1. **Authentication middleware** - Verify the driver making the request
2. **Authorization** - Ensure driver can only accept rides assigned to their area
3. **Rate limiting** - Prevent spam acceptance attempts
4. **Concurrent acceptance protection** - Already implemented via status check

---

## Troubleshooting

**Error: "Driver not found"**
- Verify the driverId exists in the drivers table
- Check the auth_user_id link is correct

**Error: "Driver is not available"**
- Check driver's is_online flag is true
- Check driver's is_available flag is true
- Verify driver isn't already on another ride

**Error: "Failed to update ride or ride already accepted"**
- Ride might already be accepted by another driver
- Check ride status is 'requested' before accepting

**Passenger not receiving updates:**
- Verify Supabase realtime is enabled
- Check ride_events table RLS policies
- Ensure passenger is subscribed to the correct ride_id channel

---

## Next Steps

1. Test the endpoint with real driver and passenger data
2. Monitor ride_events table for proper event creation
3. Verify real-time updates reach the passenger app
4. Add authentication middleware for security
5. Implement analytics/logging for acceptance metrics
