-- ============================================================================
-- BOOFER ADMIN ANALYTICS - DATABASE FUNCTIONS & VIEWS
-- ============================================================================
-- This file contains all database functions and views needed for the admin
-- dashboard to display real-time analytics and metrics.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. USER ANALYTICS FUNCTIONS
-- ============================================================================

-- Get count of active users (online in last 5 minutes)
CREATE OR REPLACE FUNCTION get_active_users_count()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM profiles
    WHERE status = 'online'
    AND last_seen > NOW() - INTERVAL '5 minutes'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user activity metrics (DAU, WAU, MAU)
CREATE OR REPLACE FUNCTION get_user_activity_metrics(period TEXT DEFAULT 'day')
RETURNS TABLE(
  active_users INTEGER,
  new_users INTEGER,
  total_users INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    -- Active users (with last_seen in period)
    COUNT(DISTINCT CASE 
      WHEN p.last_seen > NOW() - 
        CASE period
          WHEN 'day' THEN INTERVAL '1 day'
          WHEN 'week' THEN INTERVAL '7 days'
          WHEN 'month' THEN INTERVAL '30 days'
          ELSE INTERVAL '1 day'
        END
      THEN p.id
    END)::INTEGER as active_users,
    
    -- New users (created in period)
    COUNT(DISTINCT CASE 
      WHEN p.created_at > NOW() - 
        CASE period
          WHEN 'day' THEN INTERVAL '1 day'
          WHEN 'week' THEN INTERVAL '7 days'
          WHEN 'month' THEN INTERVAL '30 days'
          ELSE INTERVAL '1 day'
        END
      THEN p.id
    END)::INTEGER as new_users,
    
    -- Total users
    COUNT(*)::INTEGER as total_users
  FROM profiles p
  WHERE p.status != 'deleted';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user growth data for last N days
CREATE OR REPLACE FUNCTION get_user_growth(days INTEGER DEFAULT 30)
RETURNS TABLE(
  date DATE,
  new_users INTEGER,
  total_users INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH date_series AS (
    SELECT generate_series(
      CURRENT_DATE - (days || ' days')::INTERVAL,
      CURRENT_DATE,
      '1 day'::INTERVAL
    )::DATE as date
  ),
  daily_new_users AS (
    SELECT
      DATE(created_at) as date,
      COUNT(*)::INTEGER as new_users
    FROM profiles
    WHERE created_at >= CURRENT_DATE - (days || ' days')::INTERVAL
    AND status != 'deleted'
    GROUP BY DATE(created_at)
  )
  SELECT
    ds.date,
    COALESCE(dnu.new_users, 0) as new_users,
    (
      SELECT COUNT(*)::INTEGER
      FROM profiles
      WHERE DATE(created_at) <= ds.date
      AND status != 'deleted'
    ) as total_users
  FROM date_series ds
  LEFT JOIN daily_new_users dnu ON ds.date = dnu.date
  ORDER BY ds.date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user status distribution
CREATE OR REPLACE FUNCTION get_user_status_distribution()
RETURNS TABLE(
  status TEXT,
  count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.status::TEXT,
    COUNT(*)::INTEGER
  FROM profiles p
  WHERE p.status != 'deleted'
  GROUP BY p.status
  ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. MESSAGE ANALYTICS FUNCTIONS
-- ============================================================================

-- Get message statistics for a date range
CREATE OR REPLACE FUNCTION get_message_stats(
  start_date TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
  end_date TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE(
  total_messages BIGINT,
  encrypted_messages BIGINT,
  text_messages BIGINT,
  media_messages BIGINT,
  failed_messages BIGINT,
  avg_messages_per_user NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT as total_messages,
    COUNT(CASE WHEN is_encrypted THEN 1 END)::BIGINT as encrypted_messages,
    COUNT(CASE WHEN type = 'text' THEN 1 END)::BIGINT as text_messages,
    COUNT(CASE WHEN type IN ('image', 'video', 'audio', 'file') THEN 1 END)::BIGINT as media_messages,
    COUNT(CASE WHEN status = 'failed' THEN 1 END)::BIGINT as failed_messages,
    ROUND(
      COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT sender_id), 0),
      2
    ) as avg_messages_per_user
  FROM messages
  WHERE timestamp BETWEEN start_date AND end_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get message volume by hour (for heatmap)
CREATE OR REPLACE FUNCTION get_message_volume_by_hour()
RETURNS TABLE(
  hour INTEGER,
  day_of_week INTEGER,
  message_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(HOUR FROM timestamp)::INTEGER as hour,
    EXTRACT(DOW FROM timestamp)::INTEGER as day_of_week,
    COUNT(*)::BIGINT as message_count
  FROM messages
  WHERE timestamp > NOW() - INTERVAL '7 days'
  GROUP BY EXTRACT(HOUR FROM timestamp), EXTRACT(DOW FROM timestamp)
  ORDER BY day_of_week, hour;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get message volume over time
CREATE OR REPLACE FUNCTION get_message_volume(
  period TEXT DEFAULT 'day',
  days INTEGER DEFAULT 30
)
RETURNS TABLE(
  date TIMESTAMPTZ,
  message_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    DATE_TRUNC(period, timestamp) as date,
    COUNT(*)::BIGINT as message_count
  FROM messages
  WHERE timestamp > NOW() - (days || ' days')::INTERVAL
  GROUP BY DATE_TRUNC(period, timestamp)
  ORDER BY date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get active conversations count
CREATE OR REPLACE FUNCTION get_active_conversations_count(
  hours INTEGER DEFAULT 24
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT conversation_id)::INTEGER
    FROM messages
    WHERE timestamp > NOW() - (hours || ' hours')::INTERVAL
    AND conversation_id IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 3. SOCIAL ANALYTICS FUNCTIONS
-- ============================================================================

-- Get social metrics
CREATE OR REPLACE FUNCTION get_social_metrics()
RETURNS TABLE(
  total_follows BIGINT,
  new_follows_today BIGINT,
  avg_followers_per_user NUMERIC,
  most_followed_users JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::BIGINT FROM follows) as total_follows,
    (SELECT COUNT(*)::BIGINT FROM follows WHERE followed_at > CURRENT_DATE) as new_follows_today,
    (SELECT ROUND(AVG(follower_count), 2) FROM profiles WHERE status != 'deleted') as avg_followers_per_user,
    (
      SELECT JSONB_AGG(
        JSONB_BUILD_OBJECT(
          'id', id,
          'handle', handle,
          'full_name', full_name,
          'follower_count', follower_count
        )
      )
      FROM (
        SELECT id, handle, full_name, follower_count
        FROM profiles
        WHERE status != 'deleted'
        ORDER BY follower_count DESC
        LIMIT 10
      ) top_users
    ) as most_followed_users;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. SUPPORT ANALYTICS FUNCTIONS
-- ============================================================================

-- Get support metrics
CREATE OR REPLACE FUNCTION get_support_metrics()
RETURNS TABLE(
  open_tickets INTEGER,
  closed_tickets INTEGER,
  pending_live_chats INTEGER,
  active_live_chats INTEGER,
  total_bug_reports INTEGER,
  high_severity_bugs INTEGER,
  total_feedback INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::INTEGER FROM support_tickets WHERE status = 'open') as open_tickets,
    (SELECT COUNT(*)::INTEGER FROM support_tickets WHERE status = 'closed') as closed_tickets,
    (SELECT COUNT(*)::INTEGER FROM live_chat_requests WHERE status = 'pending') as pending_live_chats,
    (SELECT COUNT(*)::INTEGER FROM live_chat_requests WHERE status = 'accepted') as active_live_chats,
    (SELECT COUNT(*)::INTEGER FROM bug_reports) as total_bug_reports,
    (SELECT COUNT(*)::INTEGER FROM bug_reports WHERE severity = 'high') as high_severity_bugs,
    (SELECT COUNT(*)::INTEGER FROM feedback) as total_feedback;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get average ticket response time (in minutes)
CREATE OR REPLACE FUNCTION get_avg_ticket_response_time()
RETURNS NUMERIC AS $$
BEGIN
  RETURN (
    SELECT ROUND(
      AVG(
        EXTRACT(EPOCH FROM (updated_at - created_at)) / 60
      ),
      2
    )
    FROM support_tickets
    WHERE status = 'closed'
    AND updated_at > created_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. SYSTEM HEALTH FUNCTIONS
-- ============================================================================

-- Get system health metrics
CREATE OR REPLACE FUNCTION get_system_health()
RETURNS TABLE(
  total_messages BIGINT,
  failed_messages BIGINT,
  decryption_failures BIGINT,
  delivery_rate NUMERIC,
  avg_message_size NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT as total_messages,
    COUNT(CASE WHEN status = 'failed' THEN 1 END)::BIGINT as failed_messages,
    COUNT(CASE WHEN status = 'decryptionFailed' THEN 1 END)::BIGINT as decryption_failures,
    ROUND(
      (COUNT(CASE WHEN status IN ('delivered', 'read') THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0)) * 100,
      2
    ) as delivery_rate,
    ROUND(AVG(LENGTH(text)), 2) as avg_message_size
  FROM messages
  WHERE timestamp > NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 6. ANALYTICS VIEWS
-- ============================================================================

-- User activity summary view
CREATE OR REPLACE VIEW v_user_activity_summary AS
SELECT
  COUNT(*)::INTEGER as total_users,
  COUNT(CASE WHEN status = 'online' THEN 1 END)::INTEGER as online_users,
  COUNT(CASE WHEN status = 'offline' THEN 1 END)::INTEGER as offline_users,
  COUNT(CASE WHEN status = 'frozen' THEN 1 END)::INTEGER as frozen_users,
  COUNT(CASE WHEN last_seen > NOW() - INTERVAL '1 day' THEN 1 END)::INTEGER as active_today,
  COUNT(CASE WHEN last_seen > NOW() - INTERVAL '7 days' THEN 1 END)::INTEGER as active_this_week,
  COUNT(CASE WHEN last_seen > NOW() - INTERVAL '30 days' THEN 1 END)::INTEGER as active_this_month,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 day' THEN 1 END)::INTEGER as new_today,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '7 days' THEN 1 END)::INTEGER as new_this_week,
  COUNT(CASE WHEN created_at > NOW() - INTERVAL '30 days' THEN 1 END)::INTEGER as new_this_month
FROM profiles
WHERE status != 'deleted';

-- Message analytics view
CREATE OR REPLACE VIEW v_message_analytics AS
SELECT
  COUNT(*)::BIGINT as total_messages,
  COUNT(CASE WHEN timestamp > NOW() - INTERVAL '1 day' THEN 1 END)::BIGINT as messages_today,
  COUNT(CASE WHEN timestamp > NOW() - INTERVAL '7 days' THEN 1 END)::BIGINT as messages_this_week,
  COUNT(CASE WHEN timestamp > NOW() - INTERVAL '30 days' THEN 1 END)::BIGINT as messages_this_month,
  COUNT(CASE WHEN is_encrypted THEN 1 END)::BIGINT as encrypted_messages,
  COUNT(CASE WHEN type = 'text' THEN 1 END)::BIGINT as text_messages,
  COUNT(CASE WHEN type IN ('image', 'video', 'audio', 'file') THEN 1 END)::BIGINT as media_messages,
  COUNT(CASE WHEN status = 'failed' THEN 1 END)::BIGINT as failed_messages,
  COUNT(DISTINCT sender_id)::INTEGER as unique_senders,
  COUNT(DISTINCT conversation_id)::INTEGER as unique_conversations
FROM messages;

-- Support metrics view
CREATE OR REPLACE VIEW v_support_metrics AS
SELECT
  (SELECT COUNT(*)::INTEGER FROM support_tickets) as total_tickets,
  (SELECT COUNT(*)::INTEGER FROM support_tickets WHERE status = 'open') as open_tickets,
  (SELECT COUNT(*)::INTEGER FROM support_tickets WHERE status = 'closed') as closed_tickets,
  (SELECT COUNT(*)::INTEGER FROM live_chat_requests) as total_live_chat_requests,
  (SELECT COUNT(*)::INTEGER FROM live_chat_requests WHERE status = 'pending') as pending_live_chats,
  (SELECT COUNT(*)::INTEGER FROM live_chat_requests WHERE status = 'accepted') as active_live_chats,
  (SELECT COUNT(*)::INTEGER FROM live_chat_requests WHERE status = 'rejected') as rejected_live_chats,
  (SELECT COUNT(*)::INTEGER FROM bug_reports) as total_bug_reports,
  (SELECT COUNT(*)::INTEGER FROM bug_reports WHERE severity = 'high') as high_severity_bugs,
  (SELECT COUNT(*)::INTEGER FROM bug_reports WHERE severity = 'medium') as medium_severity_bugs,
  (SELECT COUNT(*)::INTEGER FROM bug_reports WHERE severity = 'low') as low_severity_bugs,
  (SELECT COUNT(*)::INTEGER FROM feedback) as total_feedback;

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users (admins only via RLS)
GRANT EXECUTE ON FUNCTION get_active_users_count() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_activity_metrics(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_growth(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_status_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION get_message_stats(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION get_message_volume_by_hour() TO authenticated;
GRANT EXECUTE ON FUNCTION get_message_volume(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_conversations_count(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_social_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION get_support_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION get_avg_ticket_response_time() TO authenticated;
GRANT EXECUTE ON FUNCTION get_system_health() TO authenticated;

-- Grant select permissions on views
GRANT SELECT ON v_user_activity_summary TO authenticated;
GRANT SELECT ON v_message_analytics TO authenticated;
GRANT SELECT ON v_support_metrics TO authenticated;

COMMIT;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Get active users count
-- SELECT get_active_users_count();

-- Get DAU/WAU/MAU
-- SELECT * FROM get_user_activity_metrics('day');
-- SELECT * FROM get_user_activity_metrics('week');
-- SELECT * FROM get_user_activity_metrics('month');

-- Get user growth for last 30 days
-- SELECT * FROM get_user_growth(30);

-- Get user status distribution
-- SELECT * FROM get_user_status_distribution();

-- Get message statistics
-- SELECT * FROM get_message_stats(NOW() - INTERVAL '7 days', NOW());

-- Get message volume by hour (heatmap data)
-- SELECT * FROM get_message_volume_by_hour();

-- Get message volume over time
-- SELECT * FROM get_message_volume('hour', 7);
-- SELECT * FROM get_message_volume('day', 30);

-- Get active conversations
-- SELECT get_active_conversations_count(24);

-- Get social metrics
-- SELECT * FROM get_social_metrics();

-- Get support metrics
-- SELECT * FROM get_support_metrics();

-- Get average ticket response time
-- SELECT get_avg_ticket_response_time();

-- Get system health
-- SELECT * FROM get_system_health();

-- Query views
-- SELECT * FROM v_user_activity_summary;
-- SELECT * FROM v_message_analytics;
-- SELECT * FROM v_support_metrics;
