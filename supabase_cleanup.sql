-- Function to cleanup expired ephemeral messages
CREATE OR REPLACE FUNCTION delete_expired_messages() RETURNS void AS $$
BEGIN
  DELETE FROM messages
  WHERE id IN (
    SELECT m.id
    FROM messages m
    JOIN user_conversations uc ON m.conversation_id = uc.conversation_id
    WHERE 
      -- After Seen Logic: Delete if read > 1 minute ago
      (uc.ephemeral_timer = 'after_seen' AND m.status = 'read' AND m.updated_at < NOW() - INTERVAL '1 minute')
      OR
      -- Timer Logic
      (uc.ephemeral_timer = '12_hours' AND m.timestamp < NOW() - INTERVAL '12 hours')
      OR
      (uc.ephemeral_timer = '24_hours' AND m.timestamp < NOW() - INTERVAL '24 hours')
      OR
      (uc.ephemeral_timer = '48_hours' AND m.timestamp < NOW() - INTERVAL '48 hours')
      OR
      (uc.ephemeral_timer = '72_hours' AND m.timestamp < NOW() - INTERVAL '72 hours')
  );
END;
$$ LANGUAGE plpgsql;

-- You can run this function manually or schedule it with pg_cron:
-- SELECT cron.schedule('*/5 * * * *', 'SELECT delete_expired_messages()');
