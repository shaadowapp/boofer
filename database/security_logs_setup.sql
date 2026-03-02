-- Security Audit Logs Table and Function
-- This creates a simple audit logging system for admin actions

-- Create the security_logs table (will skip if exists)
CREATE TABLE IF NOT EXISTS security_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id UUID NOT NULL,
    admin_email TEXT NOT NULL,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance (will skip if exists)
CREATE INDEX IF NOT EXISTS idx_security_logs_admin_id ON security_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_security_logs_action ON security_logs(action);
CREATE INDEX IF NOT EXISTS idx_security_logs_created_at ON security_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_security_logs_admin_email ON security_logs(admin_email);

-- Enable RLS (will skip if already enabled)
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists, then create new one
DROP POLICY IF EXISTS "Super admin full access to security logs" ON security_logs;

-- RLS Policies - Only super admin can read/write logs
CREATE POLICY "Super admin full access to security logs" ON security_logs
    FOR ALL USING (
        'shaadowplatforms.g92192@gmail.com' = current_setting('request.jwt.claims', true)::json->>'email'
    );

-- Drop existing functions if they exist, then create new ones
DROP FUNCTION IF EXISTS get_audit_logs(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS log_admin_action(UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT);

-- Create function to get audit logs with user info
CREATE OR REPLACE FUNCTION get_audit_logs(p_limit INTEGER DEFAULT 100, p_offset INTEGER DEFAULT 0)
RETURNS TABLE (
    id UUID,
    admin_id UUID,
    admin_email TEXT,
    action TEXT,
    resource_type TEXT,
    resource_id TEXT,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sl.id,
        sl.admin_id,
        sl.admin_email,
        sl.action,
        sl.resource_type,
        sl.resource_id,
        sl.details,
        sl.ip_address,
        sl.user_agent,
        sl.created_at
    FROM security_logs sl
    ORDER BY sl.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Create function to insert audit log
CREATE OR REPLACE FUNCTION log_admin_action(
    p_admin_id UUID,
    p_admin_email TEXT,
    p_action TEXT,
    p_resource_type TEXT DEFAULT NULL,
    p_resource_id TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO security_logs (
        admin_id,
        admin_email,
        action,
        resource_type,
        resource_id,
        details,
        ip_address,
        user_agent
    ) VALUES (
        p_admin_id,
        p_admin_email,
        p_action,
        p_resource_type,
        p_resource_id,
        p_details,
        p_ip_address::INET,
        p_user_agent
    );
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT ALL ON security_logs TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Insert some sample logs for testing (will skip if conflicts exist)
INSERT INTO security_logs (admin_id, admin_email, action, resource_type, details)
VALUES 
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'admin_login', 'auth', '{"ip": "192.168.1.1", "browser": "Chrome"}'),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'user_deleted', 'users', '{"user_id": "abc123", "reason": "spam"}'),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'settings_updated', 'system', '{"setting": "maintenance_mode", "value": "enabled"}')
ON CONFLICT DO NOTHING;

