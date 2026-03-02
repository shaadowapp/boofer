-- Minimal Security Logs Setup for Custom Admin Auth
-- This creates just what's needed for the SecurityLogs component to work

-- Drop existing table and recreate with correct structure
DROP TABLE IF EXISTS public.security_logs CASCADE;

-- Create the security_logs table with simple structure
CREATE TABLE public.security_logs (
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

-- Create indexes
CREATE INDEX idx_security_logs_admin_id ON security_logs(admin_id);
CREATE INDEX idx_security_logs_action ON security_logs(action);
CREATE INDEX idx_security_logs_created_at ON security_logs(created_at);
CREATE INDEX idx_security_logs_admin_email ON security_logs(admin_email);

-- Enable RLS
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policy and create new one for super admin only
DROP POLICY IF EXISTS "Super admin full access to security logs" ON security_logs;
CREATE POLICY "Super admin full access to security logs" ON security_logs
    FOR ALL USING (
        admin_email = 'shaadowplatforms.g92192@gmail.com'
        OR current_setting('request.jwt.claims', true)::json->>'email' = 'shaadowplatforms.g92192@gmail.com'
    );

-- Drop existing functions
DROP FUNCTION IF EXISTS get_audit_logs(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS log_admin_action(UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT);

-- Create simple get_audit_logs function that matches component expectations
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

-- Create simple log function
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
GRANT EXECUTE ON FUNCTION get_audit_logs TO authenticated;
GRANT EXECUTE ON FUNCTION log_admin_action TO authenticated;

-- Insert sample data
INSERT INTO security_logs (admin_id, admin_email, action, resource_type, details)
VALUES 
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'admin_login', 'auth', '{"ip": "192.168.1.1", "browser": "Chrome"}'::jsonb),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'user_deleted', 'users', '{"user_id": "abc123", "reason": "spam"}'::jsonb),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'settings_updated', 'system', '{"setting": "maintenance_mode", "value": "enabled"}'::jsonb),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'ticket_resolved', 'tickets', '{"ticket_id": "xyz789", "resolution": "completed"}'::jsonb),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'broadcast_sent', 'messages', '{"message_id": "msg001", "recipients": 150}'::jsonb);

COMMIT;