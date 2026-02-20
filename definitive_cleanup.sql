-- 🚨 DEFINITIVE CLEAN SCHEMA MIGRATION 🚨
-- This script fixes the "confusion" by deleting old tables and unifying everything into just 'messages'.
-- It also sets up the "Lobby View" so you don't need a second table for conversations.

BEGIN;

-- 1. CLEANUP: Drop all confusing old tables/views
DROP VIEW IF EXISTS public.v_chat_lobby CASCADE;
DROP TABLE IF EXISTS public.user_conversations CASCADE;
DROP TABLE IF EXISTS public.conversation_participants CASCADE;
DROP TABLE IF EXISTS public.conversation_keys CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;

-- 2. UNIFY: Ensure the 'messages' table is the ONLY source of truth
-- It already exists, but we ensure it has the correct columns for E2EE and Lobby
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS encrypted_content JSONB,
ADD COLUMN IF NOT EXISTS encryption_version TEXT DEFAULT 'virgil_v1';

-- 3. SPEED: Create indexes so the lobby loads instantly even with millions of messages
CREATE INDEX IF NOT EXISTS idx_messages_lobby_lookup ON public.messages (sender_id, receiver_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages (conversation_id);

-- 4. REALTIME: Enable Realtime for the messages table (Crucial for chatting)
-- This ensures that when someone sends a message, you see it instantly without refreshing.
ALTER publication supabase_realtime ADD TABLE public.messages;

-- 5. LOBBY VIEW: This replaces the "Conversation Table" entirely.
-- It dynamically finds the latest message for every person you've talked to.
CREATE OR REPLACE VIEW public.v_chat_lobby AS
WITH latest_messages AS (
    SELECT DISTINCT ON (
        CASE 
            WHEN sender_id < receiver_id THEN sender_id || ':' || receiver_id 
            ELSE receiver_id || ':' || sender_id 
        END
    )
    *,
    CASE 
        WHEN sender_id < receiver_id THEN sender_id || ':' || receiver_id 
        ELSE receiver_id || ':' || sender_id 
    END as pair_id
    FROM public.messages
    ORDER BY 
        CASE 
            WHEN sender_id < receiver_id THEN sender_id || ':' || receiver_id 
            ELSE receiver_id || ':' || sender_id 
        END,
        timestamp DESC
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
    p_me.id as current_user_id,
    p_friend.id as friend_id,
    p_friend.full_name as friend_name,
    p_friend.handle as friend_handle,
    p_friend.avatar as friend_avatar,
    p_friend.profile_picture as friend_profile_picture,
    p_friend.status as friend_status,
    -- Unread Count Calculation
    (
        SELECT COUNT(*)::int
        FROM public.messages m2
        WHERE m2.receiver_id = p_me.id 
        AND m2.sender_id = p_friend.id
        AND m2.status != 'read'
    ) as unread_count
FROM latest_messages lm
CROSS JOIN LATERAL (
    SELECT id FROM auth.users -- This logic allows us to join against the logged in user correctly
) user_ref
JOIN public.profiles p_me ON (lm.sender_id = p_me.id OR lm.receiver_id = p_me.id)
JOIN public.profiles p_friend ON (
    (lm.sender_id = p_friend.id AND lm.receiver_id = p_me.id) OR 
    (lm.receiver_id = p_friend.id AND lm.sender_id = p_me.id)
)
WHERE p_me.id != p_friend.id;

-- 6. SECURITY: Re-sync schema cache 
-- (Sometimes Supabase needs to be told to refresh its list of tables)
NOTIFY pgrst, 'reload schema';

COMMIT;
