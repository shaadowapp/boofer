-- Allow users to update messages they are involved in (sender or receiver)
-- This is required for:
-- 1. Receiver to mark messages as 'read'
-- 2. Sender to potentially edit messages (if feature enabled)
-- 3. Sender/Receiver to 'delete' messages (if soft delete is used, though we use DELETE)

CREATE POLICY "Users can update their own or received messages"
ON messages
FOR UPDATE
USING (
  auth.uid() = sender_id
  OR
  auth.uid() = receiver_id
)
WITH CHECK (
  auth.uid() = sender_id
  OR
  auth.uid() = receiver_id
);

-- Also ensure DELETE policy exists if we want client-side deletion to work
-- The user said "messages not deleting... from where messages are displaying".
-- If the client tries to delete, it needs permission.
-- Currently only INSERT and SELECT exist.

CREATE POLICY "Users can delete their own or received messages"
ON messages
FOR DELETE
USING (
  auth.uid() = sender_id
  OR
  auth.uid() = receiver_id
);
