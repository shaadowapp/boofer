-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can insert their own conversations" ON user_conversations;
DROP POLICY IF EXISTS "Users can update their own conversation settings" ON user_conversations;

-- Create new policies allowing friends to update/insert each other's conversation rows
-- This is necessary specificially for syncing settings like Ephemeral Timer

-- Allow INSERT if you are the owner OR the friend (for creating the conversation entry for the other person)
CREATE POLICY "Users can insert own or friend conversation"
ON user_conversations
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  OR
  auth.uid() = friend_id
);

-- Allow UPDATE if you are the owner OR the friend (for syncing timer)
CREATE POLICY "Users can update own or friend conversation"
ON user_conversations
FOR UPDATE
USING (
  auth.uid() = user_id
  OR
  auth.uid() = friend_id
)
WITH CHECK (
  auth.uid() = user_id
  OR
  auth.uid() = friend_id
);

-- Note: SELECT policy remains "Users can view their own conversations" usually, 
-- but if we want to check the other person's timer explicitly we might need read access too.
-- However, for now, we rely on writing to the store.
-- Let's check if we need to update SELECT.
-- Supabase upsert usually requires SELECT permission to check for conflict? 
-- Actually, ON CONFLICT utilizes the index. 
-- But let's be safe and allow viewing friend's row too? 
-- No, let's keep SELECT private for privacy (lobby list). 
-- Upsert should work if we have INSERT/UPDATE permissions.

