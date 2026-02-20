-- 🚨 BOOFER DEFINITIVE EPHEMERAL MIGRATION 🚨
-- This script unifies everything into a single source of truth for ephemeral chatting.

BEGIN;

-- 1. DROP UNNECESSARY TABLES (Reducing Confusion)
DROP VIEW IF EXISTS public.v_chat_lobby CASCADE;
DROP TABLE IF EXISTS public.user_conversations CASCADE;
DROP TABLE IF EXISTS public.conversation_participants CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;

-- 2. ENHANCE MESSAGES TABLE (The Only History Table)
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS conversation_id TEXT; -- We'll use this for grouping

-- 3. CREATE KEY & SETTINGS TABLE (The "Both Sides Keys" table)
-- Stores E2EE session keys and the chosen destruction timer.
CREATE TABLE IF NOT EXISTS public.conversation_settings (
    conversation_id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    encryption_public_key TEXT,
    signature_public_key TEXT,
    ephemeral_timer TEXT DEFAULT '24_hours',
    is_hidden BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

-- 4. TTL POLICY (Automatic Self-Destruction Visibility)
-- This makes expired messages "disappear" from all queries immediately.
-- Even if they aren't deleted yet, no one can see them.
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Messages are ephemeral" ON public.messages;
CREATE POLICY "Messages are ephemeral" 
ON public.messages 
FOR SELECT 
USING (
  (expires_at IS NULL OR expires_at > NOW()) AND
  (auth.uid() = sender_id OR auth.uid() = receiver_id)
);

-- 5. LOBBY VIEW (Combining Logic into one high-performance View)
-- Shows only the latest message that HAS NOT EXPIRED.
CREATE OR REPLACE VIEW public.v_chat_lobby AS
WITH latest_msgs AS (
    SELECT DISTINCT ON (conversation_id)
        *
    FROM public.messages
    WHERE (expires_at IS NULL OR expires_at > NOW())
    ORDER BY conversation_id, timestamp DESC
)
SELECT 
    lm.id as last_message_id,
    lm.conversation_id,
    lm.text as last_message_text,
    lm.timestamp as last_message_time,
    lm.is_encrypted as last_message_is_encrypted,
    lm.encrypted_content as last_message_encrypted_content,
    lm.sender_id as last_message_sender_id,
    -- User Info
    p_friend.id as friend_id,
    p_friend.full_name as friend_name,
    p_friend.handle as friend_handle,
    p_friend.avatar as friend_avatar,
    p_friend.profile_picture as friend_profile_picture,
    p_friend.status as friend_status,
    -- Current User Context
    auth.uid() as current_user_id,
    -- Unread Count (Only for non-expired messages)
    (
        SELECT COUNT(*)::int
        FROM public.messages m2
        WHERE m2.receiver_id = auth.uid() 
        AND m2.sender_id = p_friend.id
        AND m2.status != 'read'
        AND (m2.expires_at IS NULL OR m2.expires_at > NOW())
    ) as unread_count
FROM latest_msgs lm
JOIN public.profiles p_friend ON (
    (lm.sender_id = p_friend.id AND lm.receiver_id = auth.uid()) OR 
    (lm.receiver_id = p_friend.id AND lm.sender_id = auth.uid())
)
LEFT JOIN public.conversation_settings cs ON (lm.conversation_id = cs.conversation_id AND cs.user_id = auth.uid())
WHERE (cs.is_hidden IS NOT DISTINCT FROM false);

-- 6. PERIODIC CLEANUP (Database-side destruction)
-- Since we can't guarantee pg_cron, we'll create a function you can call 
-- or that runs on every insert to keep the DB small.
CREATE OR REPLACE FUNCTION public.cleanup_expired_messages()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM public.messages WHERE expires_at < NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_cleanup_expired ON public.messages;
CREATE TRIGGER tr_cleanup_expired
AFTER INSERT ON public.messages
FOR EACH STATEMENT
EXECUTE FUNCTION public.cleanup_expired_messages();

COMMIT;
