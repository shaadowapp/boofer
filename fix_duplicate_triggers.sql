-- Migration: Remove ALL triggers from messages table and re-apply the secure one
-- This ensures no legacy/rogue triggers are left causing RLS violations

DO $$
DECLARE
    trg record;
BEGIN
    FOR trg IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'messages' 
        AND event_object_schema = 'public'
    LOOP
        RAISE NOTICE 'Dropping trigger: %', trg.trigger_name;
        EXECUTE 'DROP TRIGGER ' || quote_ident(trg.trigger_name) || ' ON public.messages CASCADE;';
    END LOOP;
END;
$$;

-- Verify handle_new_message function exists and is SECURITY DEFINER (idempotent check)
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
DECLARE
  is_conversation_encrypted boolean;
  conversation_encrypted_content jsonb;
BEGIN
  is_conversation_encrypted := NEW.is_encrypted;
  conversation_encrypted_content := NEW.encrypted_content;

  -- Upsert for SENDER
  INSERT INTO public.user_conversations (
    user_id, friend_id, conversation_id, 
    last_message_text, last_message_time, 
    is_deleted, unread_count,
    last_message_is_encrypted, last_message_encrypted_content
  )
  VALUES (
    NEW.sender_id, NEW.receiver_id, NEW.conversation_id,
    NEW.text, NEW.timestamp,
    false, 0,
    is_conversation_encrypted, conversation_encrypted_content
  )
  ON CONFLICT (user_id, friend_id) DO UPDATE SET
    last_message_text = EXCLUDED.last_message_text,
    last_message_time = EXCLUDED.last_message_time,
    is_deleted = false,
    last_message_is_encrypted = EXCLUDED.last_message_is_encrypted,
    last_message_encrypted_content = EXCLUDED.last_message_encrypted_content;

  -- Upsert for RECEIVER
  INSERT INTO public.user_conversations (
    user_id, friend_id, conversation_id, 
    last_message_text, last_message_time, 
    is_deleted, unread_count,
    last_message_is_encrypted, last_message_encrypted_content
  )
  VALUES (
    NEW.receiver_id, NEW.sender_id, NEW.conversation_id,
    NEW.text, NEW.timestamp,
    false, 1,
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

-- Re-attach the single correct trigger
CREATE TRIGGER on_message_insert
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_message();
