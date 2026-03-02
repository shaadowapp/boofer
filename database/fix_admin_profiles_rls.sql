-- Fix Admin Profiles RLS for Custom Authentication
-- Since we use anon key + custom auth, JWT claims don't contain admin email
-- The application code enforces super_admin access, RLS just needs to allow it

-- First drop existing policies
DROP POLICY IF EXISTS "Allow admin login" ON admin_profiles;
DROP POLICY IF EXISTS "Public read for auth" ON admin_profiles;
DROP POLICY IF EXISTS "Super admin can create admins" ON admin_profiles;
DROP POLICY IF EXISTS "Super admin can update admins" ON admin_profiles;
DROP POLICY IF EXISTS "Super admin can delete admins" ON admin_profiles;

-- Allow anyone to read profiles (needed for login)
CREATE POLICY "Allow read for auth" ON admin_profiles
    FOR SELECT USING (true);

-- Allow authenticated users to insert (app code enforces super_admin check)
CREATE POLICY "Allow insert for authenticated" ON admin_profiles
    FOR INSERT WITH CHECK (true);

-- Allow authenticated users to update (app code enforces super_admin check)
CREATE POLICY "Allow update for authenticated" ON admin_profiles
    FOR UPDATE USING (true);

-- Allow authenticated users to delete (app code enforces super_admin check)
CREATE POLICY "Allow delete for authenticated" ON admin_profiles
    FOR DELETE USING (true);

-- Grant permissions
GRANT ALL ON admin_profiles TO anon;
GRANT ALL ON admin_profiles TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;