-- ============================================================================
-- GRANT ADMIN ROLE TO EXISTING USERS
-- ============================================================================
-- This script grants admin role to users by updating their raw_app_meta_data
-- in the auth.users table.
-- ============================================================================

-- Grant admin role to suryasubhrajit@gmail.com
UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
  COALESCE(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  '"admin"'::jsonb
)
WHERE email = 'suryasubhrajit@gmail.com';

-- Grant super_admin role to shaadowplatforms.g92192@gmail.com
UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
  COALESCE(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  '"super_admin"'::jsonb
)
WHERE email = 'shaadowplatforms.g92192@gmail.com';

-- Verify the changes
SELECT 
  id,
  email,
  raw_app_meta_data->>'role' as role
FROM auth.users
WHERE email IN ('suryasubhrajit@gmail.com', 'shaadowplatforms.g92192@gmail.com');

-- ============================================================================
-- HOW TO GRANT ADMIN ROLE TO OTHER USERS
-- ============================================================================

-- For any other user, run:
-- UPDATE auth.users
-- SET raw_app_meta_data = jsonb_set(
--   COALESCE(raw_app_meta_data, '{}'::jsonb),
--   '{role}',
--   '"admin"'::jsonb
-- )
-- WHERE email = 'user@example.com';

-- To revoke admin role:
-- UPDATE auth.users
-- SET raw_app_meta_data = raw_app_meta_data - 'role'
-- WHERE email = 'user@example.com';

-- ============================================================================
-- NOTE: 
-- raw_app_meta_data is server-side only and cannot be modified by users directly.
-- This is the secure way to manage admin roles in Supabase.
-- ============================================================================
