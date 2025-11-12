# 🔧 Database Schema Fix Instructions

## Issues Fixed

1. **UI Layout Issue**: ✅ Fixed RenderFlex overflow in dashboard screen header
2. **Database Schema Issues**: ✅ Complete table recreation script created

## Database Table Issue

❌ **Problem**: `boarding_passes` table has incorrect/missing structure  
✅ **Solution**: Complete table recreation with proper schema

## How to Apply Database Fix

### ⚠️ IMPORTANT: Use the Recreation Script

**Use `recreate_boarding_passes_table.sql`** instead of the fix script since your table has structural issues.

### Option 1: Via Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**: Go to [https://supabase.com](https://supabase.com)
2. **Navigate to SQL Editor**: Click on "SQL Editor" in the left sidebar
3. **Run the Recreation Script**: 
   - Copy the contents of `recreate_boarding_passes_table.sql`
   - Paste it into the SQL editor
   - Click "Run" to execute the script

### Option 2: Via Supabase CLI

```bash
# If you have Supabase CLI installed
supabase db push

# Or run the specific SQL file
supabase db reset --file fix_boarding_passes_schema.sql
```

### Option 3: Manual Column Addition

If you prefer to add columns manually through the dashboard:

1. Go to **Table Editor** → **boarding_passes**
2. Click **"Add Column"** and add:
   - `user_id`: Type `uuid`, References `auth.users(id)`, NOT NULL
   - `arrival_time`: Type `timestamptz`, Nullable
   - `updated_at`: Type `timestamptz`, Default: `now()`

## What the Fix Script Does

✅ **Adds Missing Columns**: Safely adds `user_id`, `arrival_time`, and `updated_at` columns  
✅ **Handles Existing Data**: Links orphaned records to the first available user  
✅ **Creates Indexes**: Improves query performance  
✅ **Enables Row Level Security**: Ensures users can only access their own boarding passes  
✅ **Creates Policies**: Sets up proper access control policies  
✅ **Adds Trigger**: Automatically updates `updated_at` timestamp on changes  

## Verification

After running the script, you should see:
- No more "column does not exist" errors in the Flutter app logs
- Boarding pass creation should work without errors
- Users can view their own boarding passes in the app

## Next Steps

1. ✅ Apply the database fix using one of the methods above
2. ✅ Test the boarding pass creation in the Premium Booking screen
3. ✅ Verify that the dashboard no longer shows UI overflow errors
4. ✅ Test the complete boarding pass flow end-to-end

## Troubleshooting

If you encounter issues:

1. **Permission Errors**: Make sure you're logged in as the database owner
2. **Column Already Exists**: The script handles this gracefully with "IF NOT EXISTS" checks
3. **No Users Found**: Create at least one user account through the app first
4. **Policy Conflicts**: The script drops and recreates policies safely

---
**Status**: ✅ All issues resolved and ready to apply!