-- Migration: Securely Fix RLS Violations by Updating Trigger to SECURITY DEFINER

-- 1. Ensure user_conversations table has necessary columns for E2EE metadata
ALTER TABLE public.user_conversations 
ADD COLUMN IF NOT EXISTS last_message_is_encrypted BOOLEAN DEFAULT false;

ALTER TABLE public.user_conversations 
ADD COLUMN IF NOT EXISTS last_message_encrypted_content JSONB;

-- 2. Ensure unread_count column exists (as it's used in trigger logic)
ALTER TABLE public.user_conversations 
ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0;

-- 3. Ensure unique constraint exists for ON CONFLICT clause
-- We use unique index on (user_id, friend_id) to identify conversations
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_conversations_composite 
ON public.user_conversations (user_id, friend_id);

-- 4. Define the Trigger Function as SECURITY DEFINER
-- This bypasses RLS checks on user_conversations when invoked by the trigger
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
DECLARE
  is_conversation_encrypted boolean;
  conversation_encrypted_content jsonb;
BEGIN
  is_conversation_encrypted := NEW.is_encrypted;
  conversation_encrypted_content := NEW.encrypted_content;

  -- Upsert for SENDER (User -> Friend)
  INSERT INTO public.user_conversations (
    user_id, friend_id, conversation_id, 
    last_message_text, last_message_time, 
    is_deleted, unread_count,
    last_message_is_encrypted, last_message_encrypted_content
  )
  VALUES (
    NEW.sender_id, NEW.receiver_id, NEW.conversation_id,
    NEW.text, NEW.timestamp,
    false, 0, -- Sender has read their own message (0 unread)
    is_conversation_encrypted, conversation_encrypted_content
  )
  ON CONFLICT (user_id, friend_id) DO UPDATE SET
    last_message_text = EXCLUDED.last_message_text,
    last_message_time = EXCLUDED.last_message_time,
    is_deleted = false,
    last_message_is_encrypted = EXCLUDED.last_message_is_encrypted,
    last_message_encrypted_content = EXCLUDED.last_message_encrypted_content;

  -- Upsert for RECEIVER (Friend -> User)
  INSERT INTO public.user_conversations (
    user_id, friend_id, conversation_id, 
    last_message_text, last_message_time, 
    is_deleted, unread_count,
    last_message_is_encrypted, last_message_encrypted_content
  )
  VALUES (
    NEW.receiver_id, NEW.sender_id, NEW.conversation_id,
    NEW.text, NEW.timestamp,
    false, 1, -- Start with 1 unread message if new conversation
    is_conversation_encrypted, conversation_encrypted_content
  )
  ON CONFLICT (user_id, friend_id) DO UPDATE SET
    last_message_text = EXCLUDED.last_message_text,
    last_message_time = EXCLUDED.last_message_time,
    is_deleted = false,
    unread_count = user_conversations.unread_count + 1,
    last_message_is_encrypted = EXCLUDED.last_message_is_encrypted,
    last_message_encrypted_content = EXCLUDED.last_message_encrypted_content;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Drop existing triggers to avoid conflicts or double execution
DROP TRIGGER IF EXISTS on_message_insert ON public.messages;
DROP TRIGGER IF EXISTS handle_new_message ON public.messages;
DROP TRIGGER IF EXISTS message_insert_trigger ON public.messages;

-- 6. Create the new trigger
CREATE TRIGGER on_message_insert
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_message();
