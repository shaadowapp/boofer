-- ============================================================================
-- PASSWORD RESET FLOW
-- ============================================================================
-- Run this in Supabase SQL Editor to set up password reset for admin users
-- ============================================================================

-- Step 1: Get the user IDs
SELECT id, email FROM auth.users WHERE email IN (
  'suryasubhrajit@gmail.com',
  'shaadowplatforms.g92192@gmail.com'
);

-- Step 2: For each user, run this command in the Supabase Dashboard:
-- Dashboard > Authentication > Users > [User] > Edit > Password
-- Set password to: admin123

-- Step 3: After setting password, verify the role is set:
-- Dashboard > Authentication > Users > [User] > Edit > User metadata
-- Add: {"role": "admin"} or {"role": "super_admin"}

-- ============================================================================
-- ALTERNATIVE: Use Supabase CLI (if installed)
-- ============================================================================
-- supabase auth admin update-user --email suryasubhrajit@gmail.com --password admin123
-- supabase auth admin update-user --email shaadowplatforms.g92192@gmail.com --password admin123

-- ============================================================================
-- ALTERNATIVE: Use the Auth REST API with correct service_role key
-- ============================================================================
-- curl -X POST "https://fvjdohkfaxomtosiibua.supabase.co/auth/v1/admin/users/[USER_ID]" \
--   -H "apikey: [SERVICE_ROLE_KEY]" \
--   -H "Authorization: Bearer [SERVICE_ROLE_KEY]" \
--   -H "Content-Type: application/json" \
--   -d '{"password": "admin123"}'

-- ============================================================================
-- NOTE: The service_role key can be found in:
-- Dashboard > Project Settings > API
-- Look for "service_role" key (not anon or public)
-- ============================================================================
