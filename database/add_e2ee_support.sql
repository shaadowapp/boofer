-- Migration: Add E2EE Support
-- Create table to store user public key bundles for end-to-end encryption
-- This enables users to exchange encryption keys for secure messaging

-- Create user_public_keys table
CREATE TABLE IF NOT EXISTS public.user_public_keys (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    key_bundle JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_public_keys_user_id 
ON public.user_public_keys(user_id);

-- Enable RLS (Row Level Security)
ALTER TABLE public.user_public_keys ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all public keys (they're public!)
CREATE POLICY "Public keys are viewable by everyone" 
ON public.user_public_keys 
FOR SELECT 
USING (true);

-- Policy: Users can only insert/update their own public key
CREATE POLICY "Users can manage their own public keys" 
ON public.user_public_keys 
FOR ALL 
USING (auth.uid() = user_id);

-- Add encryption fields to messages table
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS encrypted_content JSONB,
ADD COLUMN IF NOT EXISTS encryption_version TEXT DEFAULT '1.0';

-- Create index on is_encrypted for efficient queries
CREATE INDEX IF NOT EXISTS idx_messages_is_encrypted 
ON public.messages(is_encrypted);

-- Add comments for documentation
COMMENT ON TABLE public.user_public_keys IS 'Stores user public key bundles for Signal Protocol E2EE';
COMMENT ON COLUMN public.messages.is_encrypted IS 'Indicates if message uses end-to-end encryption';
COMMENT ON COLUMN public.messages.encrypted_content IS 'Encrypted message payload (Signal Protocol ciphertext)';
COMMENT ON COLUMN public.messages.encryption_version IS 'Version of encryption protocol used';
