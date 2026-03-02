-- COMPLETE CLEANUP AND SETUP SCRIPT
-- This will completely reset the security logs system

-- First, drop everything that might conflict
DROP TABLE IF EXISTS public.security_logs CASCADE;
DROP TABLE IF EXISTS public.admin_audit_logs CASCADE;
DROP TABLE IF EXISTS public.system_health_snapshots CASCADE;

-- AGGRESSIVE FUNCTION CLEANUP - Drop ALL versions using DO block
DO $$
DECLARE
    func_record RECORD;
BEGIN
    -- Drop all get_audit_logs functions
    FOR func_record IN 
        SELECT oid::regprocedure::text as func_sig
        FROM pg_proc 
        WHERE proname = 'get_audit_logs'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.func_sig || ' CASCADE';
    END LOOP;
    
    -- Drop all log_admin_action functions
    FOR func_record IN 
        SELECT oid::regprocedure::text as func_sig
        FROM pg_proc 
        WHERE proname = 'log_admin_action'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.func_sig || ' CASCADE';
    END LOOP;
END $$;

-- Now create clean, simple structure
CREATE TABLE public.security_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id UUID NOT NULL,
    admin_email TEXT NOT NULL,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_security_logs_admin_id ON security_logs(admin_id);
CREATE INDEX idx_security_logs_admin_email ON security_logs(admin_email);
CREATE INDEX idx_security_logs_action ON security_logs(action);
CREATE INDEX idx_security_logs_created_at ON security_logs(created_at DESC);

-- Enable RLS
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;

-- Create policy for super admin only
CREATE POLICY "Super admin full access" ON security_logs
    FOR ALL USING (
        admin_email = 'shaadowplatforms.g92192@gmail.com'
    );

-- Create the EXACT function signature the component expects
CREATE OR REPLACE FUNCTION get_audit_logs(p_limit INTEGER DEFAULT 100, p_offset INTEGER DEFAULT 0)
RETURNS SETOF security_logs AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM security_logs
    ORDER BY created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Create log function
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
        p_ip_address,
        p_user_agent
    );
END;
$$ LANGUAGE plpgsql;

-- Set permissions
GRANT ALL ON security_logs TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_logs(INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION log_admin_action(UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT) TO authenticated;

-- Insert test data
INSERT INTO security_logs (admin_id, admin_email, action, resource_type, details, ip_address)
VALUES 
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'admin_login', 'auth', '{"status": "success", "method": "email/password"}'::jsonb, '192.168.1.100'),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'user_banned', 'users', '{"user_id": "user_123", "reason": "spam"}'::jsonb, '192.168.1.100'),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'system_restarted', 'system', '{"service": "api_server", "duration": "2.5s"}'::jsonb, '192.168.1.100'),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'ticket_closed', 'support', '{"ticket_id": "TKT-001", "resolution": "resolved"}'::jsonb, '192.168.1.100'),
    (gen_random_uuid(), 'shaadowplatforms.g92192@gmail.com', 'broadcast_sent', 'messages', '{"message_id": "MSG-001", "recipients": 247}'::jsonb, '192.168.1.100');

-- Test the function to make sure it works
SELECT COUNT(*) as log_count FROM security_logs;
SELECT * FROM get_audit_logs(3, 0);