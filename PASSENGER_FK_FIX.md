# Passenger Foreign Key Constraint Fix

## Problem

When clicking "Confirm Ride" in the passenger app, the following error occurred:

```
Failed to create ride:
PostgrestException(message: insert or update on table "rides" violates foreign key constraint 
"rides_passenger_id_fkey", code: 23503, details: Key is not present in table "passengers", hint: null)
```

## Root Cause

The `rides` table has a foreign key constraint on `passenger_id` that references the `passengers` table. When the backend tried to create a ride, it was failing because:

1. The passenger record didn't exist in the `passengers` table
2. The previous upsert logic was silently failing and falling back to using the auth user ID directly
3. The auth user ID doesn't exist as a primary key in the `passengers` table

## Solution

### Backend Changes (driverHandler.ts)

Improved the `saveRideToDatabase()` function to:

1. **Check if passenger exists** using `auth_user_id`
2. **If exists**: Use their `id` and update their info
3. **If not exists**: Create new passenger record and get the `id`
4. **Proper error handling**: Throw errors if passenger creation fails (instead of silently continuing)

**Key improvements:**
- Use `maybeSingle()` instead of `upsert()` for clearer logic
- Separate check → update/insert flow for better error tracking
- Throw descriptive errors when passenger creation fails
- Log passenger creation/update status for debugging

### Passenger App Changes (confirm_ride_screen.dart)

1. **Added error stream listener**: Listen for `ride_request_failed` events from backend
2. **Improved cleanup**: Cancel both submission and error subscriptions on timeout
3. **Better error messages**: Show backend error messages to users

## Database Schema Context

The `passengers` table structure:
```sql
CREATE TABLE passengers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID UNIQUE,  -- References auth.users
  name TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

The `rides` table has:
```sql
passenger_id UUID REFERENCES passengers(id)
```

**Key point**: The ride's `passenger_id` must reference `passengers.id` (the UUID primary key), NOT `passengers.auth_user_id` or `auth.users.id`.

## Flow After Fix

1. **Passenger App** sends ride request with `passenger_id` = Supabase auth user ID
2. **Backend** receives request:
   - Checks if passenger exists with that `auth_user_id`
   - If yes: Uses their `passengers.id`
   - If no: Creates passenger record, gets generated `passengers.id`
3. **Backend** creates ride with correct `passenger_id` referencing `passengers.id`
4. **Database** accepts the insert (foreign key constraint satisfied)
5. **Backend** broadcasts to drivers
6. **Passenger App** receives confirmation and navigates to searching screen

## Testing

After deployment:

1. ✅ Check backend logs for passenger creation
2. ✅ Verify ride creation succeeds
3. ✅ Confirm no foreign key errors
4. ✅ Test with existing passenger (should update)
5. ✅ Test with new passenger (should create)

## Deployment

Backend changes committed and pushed to GitHub:
- Commit: `309d64c` - "Fix passenger creation: ensure passenger record exists before creating ride"
- Branch: `master`
- Auto-deploys to Render.com

Wait ~5-10 minutes for Render to deploy the changes, then test the passenger app.

## Error Handling Flow

### Before Fix
```
Passenger → Backend → Upsert fails silently → Uses wrong ID → Database rejects → Generic error
```

### After Fix
```
Passenger → Backend → Check exists → Create/Update → Get correct ID → Database accepts → Success
                                  ↓ (if fails)
                            Throw clear error → Passenger sees message
```

## Prevention

To prevent similar issues in the future:

1. Always check foreign key constraints when creating records
2. Use explicit check → insert/update instead of blind upserts
3. Log passenger/driver/ride creation for debugging
4. Return descriptive errors to the client
5. Test with fresh users (who don't have passenger records yet)
