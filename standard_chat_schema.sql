-- Migration: Industry Standard Unified Chat Schema
-- This combines "lobby" and "messages" logic using Views and a Metadata table.

BEGIN;

-- 1. Shared Conversations Table
-- This stores the stable metadata for a chat session.
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    encryption_type TEXT DEFAULT 'virgil_v1',
    metadata JSONB DEFAULT '{}'
);

-- 2. Conversation Participants (Many-to-Many)
-- This allows for 1-to-1 or Groups.
CREATE TABLE IF NOT EXISTS public.conversation_participants (
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT false,
    PRIMARY KEY (conversation_id, user_id)
);

-- 3. Conversation Keys (Industry Standard: Store participant public keys per conversation)
-- This "locks" the keys for a session, preventing "Active Man-in-the-Middle" by key swapping.
CREATE TABLE IF NOT EXISTS public.conversation_keys (
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    encryption_public_key TEXT NOT NULL, -- Base64
    signature_public_key TEXT NOT NULL,  -- Base64
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

-- 4. Unified Messages Table
-- Optimized for E2EE storage.
-- Ensure columns exist in the existing messages table if we are migrating, 
-- but here we define the ideal structure.
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE;

-- 5. Lobby View (The "Combined" experience)
-- This dynamically calculates the latest message, friend info, and unread count.
-- Frontend only needs to query this VIEW to get the lobby.
CREATE OR REPLACE VIEW public.v_chat_lobby AS
SELECT 
    c.id AS conversation_id,
    p_me.user_id AS current_user_id,
    p_friend.user_id AS friend_id,
    profiles.full_name AS friend_name,
    profiles.handle AS friend_handle,
    profiles.avatar AS friend_avatar,
    profiles.profile_picture AS friend_profile_picture,
    profiles.status AS friend_status,
    m.text AS last_message_text,
    m.timestamp AS last_message_time,
    m.is_encrypted AS last_message_is_encrypted,
    m.encrypted_content AS last_message_encrypted_content,
    (
        SELECT COUNT(*) 
        FROM public.messages m2 
        WHERE m2.conversation_id = c.id 
        AND m2.sender_id = p_friend.user_id 
        AND m2.timestamp > p_me.last_read_at
    ) AS unread_count
FROM public.conversations c
JOIN public.conversation_participants p_me ON c.id = p_me.conversation_id
JOIN public.conversation_participants p_friend ON c.id = p_friend.conversation_id AND p_friend.user_id != p_me.user_id
JOIN public.profiles ON p_friend.user_id = profiles.id
LEFT JOIN LATERAL (
    SELECT * FROM public.messages m_inner 
    WHERE m_inner.conversation_id = c.id 
    ORDER BY m_inner.timestamp DESC 
    LIMIT 1
) m ON true
WHERE p_me.is_deleted = false;

-- 6. Trigger to automate conversation ID creation on first message (Compatibility Layer)
CREATE OR REPLACE FUNCTION public.auto_setup_conversation()
RETURNS TRIGGER AS $$
DECLARE
    conv_id UUID;
BEGIN
    -- If conversation_id is missing, find or create one based on sender/receiver
    IF NEW.conversation_id IS NULL THEN
        -- Find existing 1-to-1 conversation
        SELECT cp1.conversation_id INTO conv_id
        FROM public.conversation_participants cp1
        JOIN public.conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
        WHERE cp1.user_id = NEW.sender_id AND cp2.user_id = NEW.receiver_id
        LIMIT 1;

        -- Create if none exists
        IF conv_id IS NULL THEN
            INSERT INTO public.conversations (encryption_type) VALUES ('virgil_v1') RETURNING id INTO conv_id;
            INSERT INTO public.conversation_participants (conversation_id, user_id) VALUES (conv_id, NEW.sender_id), (conv_id, NEW.receiver_id);
            
            -- Store initial keys (The "Encryption Keys from both side" table)
            INSERT INTO public.conversation_keys (conversation_id, user_id, encryption_public_key, signature_public_key)
            SELECT conv_id, user_id, (key_bundle->>'encryptionPublicKey'), (key_bundle->>'signaturePublicKey')
            FROM public.user_public_keys
            WHERE user_id IN (NEW.sender_id, NEW.receiver_id);
        END IF;

        NEW.conversation_id := conv_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_auto_setup_conversation ON public.messages;
CREATE TRIGGER tr_auto_setup_conversation
BEFORE INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.auto_setup_conversation();

-- 7. Add Comment
COMMENT ON VIEW public.v_chat_lobby IS 'Unified Lobby View: Combines messages and conversation metadata for a simplified frontend experience.';

COMMIT;
