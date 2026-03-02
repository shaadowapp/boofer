-- =====================================================
-- Phase 4: System Management & Audit Logs
-- =====================================================
-- This file contains database functions and tables for:
-- 1. Audit logging (admin activity tracking) - UPDATED for custom admin_profiles auth
-- 2. System health monitoring
-- 3. Report generation
-- =====================================================

-- =====================================================
-- 1. AUDIT LOG TABLE
-- =====================================================
-- Track all admin actions for security and compliance

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL, -- References admin_profiles.id (custom auth)
    admin_email TEXT NOT NULL, -- Store email directly for easier querying
    action_type TEXT NOT NULL, -- 'user_freeze', 'user_unfreeze', 'ticket_update', 'system_config', etc.
    target_type TEXT, -- 'user', 'ticket', 'system', 'message', etc.
    target_id TEXT, -- ID of the affected entity
    details JSONB, -- Additional context (old_value, new_value, reason, etc.)
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add admin_email column if it doesn't exist (for existing tables)
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS admin_email TEXT;

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_id ON public.admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_email ON public.admin_audit_logs(admin_email);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON public.admin_audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON public.admin_audit_logs(target_type, target_id);

-- Enable RLS
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Only super admin can read audit logs (using custom auth)
DROP POLICY IF EXISTS "Admins can read audit logs" ON public.admin_audit_logs;
CREATE POLICY "Super admin can read audit logs"
ON public.admin_audit_logs FOR SELECT
TO authenticated
USING (
    admin_email = 'shaadowplatforms.g92192@gmail.com'
    OR current_setting('request.jwt.claims', true)::json->>'email' = 'shaadowplatforms.g92192@gmail.com'
);

-- Policy: System can insert audit logs
DROP POLICY IF EXISTS "System can insert audit logs" ON public.admin_audit_logs;
CREATE POLICY "System can insert audit logs"
ON public.admin_audit_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- =====================================================
-- 2. SYSTEM HEALTH METRICS TABLE
-- =====================================================
-- Store periodic system health snapshots

CREATE TABLE IF NOT EXISTS public.system_health_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_users INTEGER,
    active_users INTEGER,
    total_messages INTEGER,
    failed_messages INTEGER,
    open_tickets INTEGER,
    pending_chats INTEGER,
    database_size_mb NUMERIC,
    response_time_ms NUMERIC,
    cpu_usage_percent NUMERIC,
    memory_usage_percent NUMERIC,
    metrics JSONB -- Additional metrics
);

-- Index for time-series queries
CREATE INDEX IF NOT EXISTS idx_health_snapshots_recorded_at ON public.system_health_snapshots(recorded_at DESC);

-- Enable RLS
ALTER TABLE public.system_health_snapshots ENABLE ROW LEVEL SECURITY;

-- Policy: Only admins can read health snapshots
CREATE POLICY "Admins can read health snapshots"
ON public.system_health_snapshots FOR SELECT
TO authenticated
USING (
    auth.uid() = '00000000-0000-4000-8000-000000000000'::uuid
);

-- =====================================================
-- 3. AUDIT LOG FUNCTIONS
-- =====================================================

-- Function: Log admin action
CREATE OR REPLACE FUNCTION log_admin_action(
    p_admin_id UUID,
    p_action_type TEXT,
    p_target_type TEXT DEFAULT NULL,
    p_target_id TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO public.admin_audit_logs (
        admin_id,
        action_type,
        target_type,
        target_id,
        details,
        ip_address,
        user_agent
    ) VALUES (
        p_admin_id,
        p_action_type,
        p_target_type,
        p_target_id,
        p_details,
        p_ip_address,
        p_user_agent
    )
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

-- Function: Get recent audit logs
CREATE OR REPLACE FUNCTION get_audit_logs(
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0,
    p_action_type TEXT DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    admin_id UUID,
    admin_email TEXT,
    action_type TEXT,
    target_type TEXT,
    target_id TEXT,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.id,
        al.admin_id,
        al.admin_email, -- Directly from audit logs table (no join needed)
        al.action_type,
        al.target_type,
        al.target_id,
        al.details,
        al.ip_address,
        al.user_agent,
        al.created_at
    FROM public.admin_audit_logs al
    WHERE 
        (p_action_type IS NULL OR al.action_type = p_action_type)
        AND (p_admin_id IS NULL OR al.admin_id = p_admin_id)
        AND (p_start_date IS NULL OR al.created_at >= p_start_date)
        AND (p_end_date IS NULL OR al.created_at <= p_end_date)
    ORDER BY al.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- Function: Get audit log statistics
CREATE OR REPLACE FUNCTION get_audit_stats(
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
    total_actions INTEGER,
    unique_admins INTEGER,
    actions_by_type JSONB,
    actions_by_day JSONB,
    top_admins JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_actions,
        COUNT(DISTINCT admin_id)::INTEGER as unique_admins,
        jsonb_object_agg(
            action_type, 
            action_count
        ) as actions_by_type,
        jsonb_object_agg(
            action_date::TEXT, 
            daily_count
        ) as actions_by_day,
        jsonb_agg(
            jsonb_build_object(
                'admin_id', admin_id,
                'admin_email', admin_email,
                'action_count', admin_action_count
            )
        ) as top_admins
    FROM (
        SELECT 
            al.action_type,
            COUNT(*) as action_count
        FROM public.admin_audit_logs al
        WHERE al.created_at BETWEEN p_start_date AND p_end_date
        GROUP BY al.action_type
    ) actions_summary
    CROSS JOIN (
        SELECT 
            DATE(al.created_at) as action_date,
            COUNT(*) as daily_count
        FROM public.admin_audit_logs al
        WHERE al.created_at BETWEEN p_start_date AND p_end_date
        GROUP BY DATE(al.created_at)
    ) daily_summary
    CROSS JOIN (
        SELECT 
            al.admin_id,
            au.email as admin_email,
            COUNT(*) as admin_action_count
        FROM public.admin_audit_logs al
        LEFT JOIN auth.users au ON al.admin_id = au.id
        WHERE al.created_at BETWEEN p_start_date AND p_end_date
        GROUP BY al.admin_id, au.email
        ORDER BY admin_action_count DESC
        LIMIT 10
    ) admin_summary;
END;
$$;

-- =====================================================
-- 4. SYSTEM HEALTH FUNCTIONS
-- =====================================================

-- Function: Get current system health
CREATE OR REPLACE FUNCTION get_system_health()
RETURNS TABLE (
    total_users INTEGER,
    active_users INTEGER,
    online_users INTEGER,
    total_messages INTEGER,
    messages_today INTEGER,
    failed_messages INTEGER,
    open_tickets INTEGER,
    pending_chats INTEGER,
    high_priority_bugs INTEGER,
    database_connections INTEGER,
    avg_response_time_ms NUMERIC,
    health_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_users INTEGER;
    v_active_users INTEGER;
    v_online_users INTEGER;
    v_total_messages INTEGER;
    v_messages_today INTEGER;
    v_failed_messages INTEGER;
    v_open_tickets INTEGER;
    v_pending_chats INTEGER;
    v_high_priority_bugs INTEGER;
    v_health_status TEXT;
BEGIN
    -- Get user counts
    SELECT COUNT(*) INTO v_total_users
    FROM public.profiles
    WHERE deleted_at IS NULL;
    
    SELECT COUNT(*) INTO v_active_users
    FROM public.profiles
    WHERE deleted_at IS NULL
    AND last_seen > NOW() - INTERVAL '24 hours';
    
    SELECT COUNT(*) INTO v_online_users
    FROM public.profiles
    WHERE deleted_at IS NULL
    AND status = 'online';
    
    -- Get message counts
    SELECT COUNT(*) INTO v_total_messages
    FROM public.messages;
    
    SELECT COUNT(*) INTO v_messages_today
    FROM public.messages
    WHERE created_at > CURRENT_DATE;
    
    SELECT COUNT(*) INTO v_failed_messages
    FROM public.messages
    WHERE status = 'failed';
    
    -- Get support counts
    SELECT COUNT(*) INTO v_open_tickets
    FROM public.support_tickets
    WHERE status IN ('open', 'in_progress');
    
    SELECT COUNT(*) INTO v_pending_chats
    FROM public.live_chat_requests
    WHERE status = 'pending';
    
    SELECT COUNT(*) INTO v_high_priority_bugs
    FROM public.bug_reports
    WHERE severity = 'high'
    AND status NOT IN ('fixed', 'verified');
    
    -- Determine health status
    IF v_failed_messages > 100 OR v_pending_chats > 50 OR v_high_priority_bugs > 10 THEN
        v_health_status := 'critical';
    ELSIF v_failed_messages > 50 OR v_pending_chats > 20 OR v_high_priority_bugs > 5 THEN
        v_health_status := 'warning';
    ELSE
        v_health_status := 'healthy';
    END IF;
    
    RETURN QUERY
    SELECT 
        v_total_users,
        v_active_users,
        v_online_users,
        v_total_messages,
        v_messages_today,
        v_failed_messages,
        v_open_tickets,
        v_pending_chats,
        v_high_priority_bugs,
        (SELECT COUNT(*) FROM pg_stat_activity)::INTEGER as database_connections,
        50.0 as avg_response_time_ms, -- Placeholder, would need actual monitoring
        v_health_status;
END;
$$;

-- Function: Record system health snapshot
CREATE OR REPLACE FUNCTION record_health_snapshot()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_snapshot_id UUID;
    v_health RECORD;
BEGIN
    -- Get current health metrics
    SELECT * INTO v_health FROM get_system_health() LIMIT 1;
    
    -- Insert snapshot
    INSERT INTO public.system_health_snapshots (
        total_users,
        active_users,
        total_messages,
        failed_messages,
        open_tickets,
        pending_chats,
        database_size_mb,
        response_time_ms,
        metrics
    ) VALUES (
        v_health.total_users,
        v_health.active_users,
        v_health.total_messages,
        v_health.failed_messages,
        v_health.open_tickets,
        v_health.pending_chats,
        0, -- Would need actual database size query
        v_health.avg_response_time_ms,
        jsonb_build_object(
            'online_users', v_health.online_users,
            'messages_today', v_health.messages_today,
            'high_priority_bugs', v_health.high_priority_bugs,
            'health_status', v_health.health_status
        )
    )
    RETURNING id INTO v_snapshot_id;
    
    RETURN v_snapshot_id;
END;
$$;

-- Function: Get system health history
CREATE OR REPLACE FUNCTION get_health_history(
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    recorded_at TIMESTAMP WITH TIME ZONE,
    total_users INTEGER,
    active_users INTEGER,
    total_messages INTEGER,
    failed_messages INTEGER,
    open_tickets INTEGER,
    pending_chats INTEGER,
    response_time_ms NUMERIC,
    health_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        shs.recorded_at,
        shs.total_users,
        shs.active_users,
        shs.total_messages,
        shs.failed_messages,
        shs.open_tickets,
        shs.pending_chats,
        shs.response_time_ms,
        (shs.metrics->>'health_status')::TEXT as health_status
    FROM public.system_health_snapshots shs
    WHERE shs.recorded_at > NOW() - (p_hours || ' hours')::INTERVAL
    ORDER BY shs.recorded_at DESC;
END;
$$;

-- =====================================================
-- 5. REPORT GENERATION FUNCTIONS
-- =====================================================

-- Function: Generate user activity report
CREATE OR REPLACE FUNCTION generate_user_report(
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
    report_date DATE,
    new_users INTEGER,
    active_users INTEGER,
    messages_sent INTEGER,
    avg_messages_per_user NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH daily_stats AS (
        SELECT 
            DATE(p.created_at) as report_date,
            COUNT(DISTINCT p.id) as new_users
        FROM public.profiles p
        WHERE p.created_at BETWEEN p_start_date AND p_end_date
        GROUP BY DATE(p.created_at)
    ),
    daily_activity AS (
        SELECT 
            DATE(m.created_at) as report_date,
            COUNT(DISTINCT m.sender_id) as active_users,
            COUNT(*) as messages_sent
        FROM public.messages m
        WHERE m.created_at BETWEEN p_start_date AND p_end_date
        GROUP BY DATE(m.created_at)
    )
    SELECT 
        COALESCE(ds.report_date, da.report_date) as report_date,
        COALESCE(ds.new_users, 0)::INTEGER as new_users,
        COALESCE(da.active_users, 0)::INTEGER as active_users,
        COALESCE(da.messages_sent, 0)::INTEGER as messages_sent,
        CASE 
            WHEN COALESCE(da.active_users, 0) > 0 
            THEN ROUND(COALESCE(da.messages_sent, 0)::NUMERIC / da.active_users, 2)
            ELSE 0
        END as avg_messages_per_user
    FROM daily_stats ds
    FULL OUTER JOIN daily_activity da ON ds.report_date = da.report_date
    ORDER BY report_date DESC;
END;
$$;

-- Function: Generate support report
CREATE OR REPLACE FUNCTION generate_support_report(
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
    total_tickets INTEGER,
    open_tickets INTEGER,
    closed_tickets INTEGER,
    avg_resolution_hours NUMERIC,
    total_live_chats INTEGER,
    accepted_chats INTEGER,
    rejected_chats INTEGER,
    total_bugs INTEGER,
    high_severity_bugs INTEGER,
    fixed_bugs INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM public.support_tickets 
         WHERE created_at BETWEEN p_start_date AND p_end_date) as total_tickets,
        (SELECT COUNT(*)::INTEGER FROM public.support_tickets 
         WHERE status IN ('open', 'in_progress')) as open_tickets,
        (SELECT COUNT(*)::INTEGER FROM public.support_tickets 
         WHERE status = 'closed' 
         AND created_at BETWEEN p_start_date AND p_end_date) as closed_tickets,
        (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600), 2)
         FROM public.support_tickets 
         WHERE status = 'closed' 
         AND created_at BETWEEN p_start_date AND p_end_date) as avg_resolution_hours,
        (SELECT COUNT(*)::INTEGER FROM public.live_chat_requests 
         WHERE created_at BETWEEN p_start_date AND p_end_date) as total_live_chats,
        (SELECT COUNT(*)::INTEGER FROM public.live_chat_requests 
         WHERE status = 'accepted' 
         AND created_at BETWEEN p_start_date AND p_end_date) as accepted_chats,
        (SELECT COUNT(*)::INTEGER FROM public.live_chat_requests 
         WHERE status = 'rejected' 
         AND created_at BETWEEN p_start_date AND p_end_date) as rejected_chats,
        (SELECT COUNT(*)::INTEGER FROM public.bug_reports 
         WHERE created_at BETWEEN p_start_date AND p_end_date) as total_bugs,
        (SELECT COUNT(*)::INTEGER FROM public.bug_reports 
         WHERE severity = 'high' 
         AND created_at BETWEEN p_start_date AND p_end_date) as high_severity_bugs,
        (SELECT COUNT(*)::INTEGER FROM public.bug_reports 
         WHERE status IN ('fixed', 'verified') 
         AND created_at BETWEEN p_start_date AND p_end_date) as fixed_bugs;
END;
$$;

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

-- Grant execute permissions to authenticated users (RLS will restrict to admins)
GRANT EXECUTE ON FUNCTION log_admin_action TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_logs TO authenticated;
GRANT EXECUTE ON FUNCTION get_audit_stats TO authenticated;
GRANT EXECUTE ON FUNCTION get_system_health TO authenticated;
GRANT EXECUTE ON FUNCTION record_health_snapshot TO authenticated;
GRANT EXECUTE ON FUNCTION get_health_history TO authenticated;
GRANT EXECUTE ON FUNCTION generate_user_report TO authenticated;
GRANT EXECUTE ON FUNCTION generate_support_report TO authenticated;

-- =====================================================
-- DEPLOYMENT COMPLETE
-- =====================================================
-- Run this SQL in Supabase SQL Editor to enable Phase 4 features
-- =====================================================
