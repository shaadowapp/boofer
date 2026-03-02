-- Admin Profiles Table Schema
-- This table stores custom admin authentication data
-- Only shaadowplatforms.g92192@gmail.com can manage other admins

-- Create the admin_profiles table
CREATE TABLE IF NOT EXISTS admin_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL, -- Hashed password
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin', 'moderator')),
    is_active BOOLEAN DEFAULT true,
    created_by TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_is_active ON admin_profiles(is_active);

-- Enable RLS (Row Level Security)
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Authentication
-- Allow anyone to read their own profile for login purposes
CREATE POLICY "Allow admin login" ON admin_profiles
    FOR SELECT USING (
        email = current_setting('request.jwt.claims', true)::json->>'email'
        OR email = 'shaadowplatforms.g92192@gmail.com'  -- Allow super admin to read any profile
        OR created_by = 'system'  -- Allow system-created records to be readable during init
    );

-- Allow anyone to read profiles for authentication (more permissive for login)
CREATE POLICY "Public read for auth" ON admin_profiles
    FOR SELECT USING (true);

-- Only super admin can insert new admins
CREATE POLICY "Super admin can create admins" ON admin_profiles
    FOR INSERT WITH CHECK (
        current_setting('request.jwt.claims', true)::json->>'email' = 'shaadowplatforms.g92192@gmail.com'
        OR created_by = 'system'
        OR current_user = 'postgres'
    );

-- Only super admin can update admins
CREATE POLICY "Super admin can update admins" ON admin_profiles
    FOR UPDATE USING (
        current_setting('request.jwt.claims', true)::json->>'email' = 'shaadowplatforms.g92192@gmail.com'
    );

-- Only super admin can delete admins
CREATE POLICY "Super admin can delete admins" ON admin_profiles
    FOR DELETE USING (
        current_setting('request.jwt.claims', true)::json->>'email' = 'shaadowplatforms.g92192@gmail.com'
    );

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_admin_profiles_updated_at 
    BEFORE UPDATE ON admin_profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert the initial super admin (run this once)
INSERT INTO admin_profiles (email, password, name, role, is_active, created_by)
VALUES (
    'shaadowplatforms.g92192@gmail.com',
    '2025175457', -- Simple hash of 'Admin@123'
    'Super Administrator',
    'super_admin',
    true,
    'system'
)
ON CONFLICT (email) DO NOTHING; -- Prevent duplicate key errors

-- Grant necessary permissions
GRANT ALL ON admin_profiles TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
