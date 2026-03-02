-- Create live_chat_requests table for managing live chat escalation requests
CREATE TABLE IF NOT EXISTS live_chat_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_live_chat_requests_user_id ON live_chat_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_live_chat_requests_status ON live_chat_requests(status);
CREATE INDEX IF NOT EXISTS idx_live_chat_requests_created_at ON live_chat_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE live_chat_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own requests
CREATE POLICY "Users can view own live chat requests"
    ON live_chat_requests
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can create their own requests
CREATE POLICY "Users can create live chat requests"
    ON live_chat_requests
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Admins can view all requests
-- Using the Boofer admin ID (00000000-0000-4000-8000-000000000000)
CREATE POLICY "Admins can view all live chat requests"
    ON live_chat_requests
    FOR SELECT
    USING (
        auth.uid() = '00000000-0000-4000-8000-000000000000'::uuid
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.id = '00000000-0000-4000-8000-000000000000'::uuid
        )
    );

-- Policy: Admins can update request status
CREATE POLICY "Admins can update live chat requests"
    ON live_chat_requests
    FOR UPDATE
    USING (
        auth.uid() = '00000000-0000-4000-8000-000000000000'::uuid
    )
    WITH CHECK (
        auth.uid() = '00000000-0000-4000-8000-000000000000'::uuid
    );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_live_chat_request_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    
    -- Set accepted_at or rejected_at based on status change
    IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
        NEW.accepted_at = NOW();
    ELSIF NEW.status = 'rejected' AND OLD.status != 'rejected' THEN
        NEW.rejected_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the timestamp update function
CREATE TRIGGER update_live_chat_request_timestamp_trigger
    BEFORE UPDATE ON live_chat_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_live_chat_request_timestamp();

-- Comment on table
COMMENT ON TABLE live_chat_requests IS 'Manages live chat escalation requests from users to support agents';
COMMENT ON COLUMN live_chat_requests.status IS 'Request status: pending (waiting for agent), accepted (agent connected), rejected (no agents available)';
