# Supabase Integration Plan for Boofer

## Why Supabase?
- Open source Firebase alternative
- PostgreSQL database with real-time subscriptions
- Built-in authentication and row-level security
- REST and GraphQL APIs
- Self-hostable for privacy

## Implementation Steps

### 1. Add Supabase Dependencies
```yaml
dependencies:
  supabase_flutter: ^2.0.0
  postgrest: ^2.0.0
  realtime_client: ^2.0.0
```

### 2. Database Schema (PostgreSQL)
```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  virtual_number TEXT UNIQUE NOT NULL,
  handle TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  bio TEXT,
  is_discoverable BOOLEAN DEFAULT true,
  status TEXT DEFAULT 'offline',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Messages table with real-time subscriptions
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  text TEXT NOT NULL,
  sender_id UUID REFERENCES users(id),
  receiver_id UUID REFERENCES users(id),
  conversation_id TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'sent',
  message_type TEXT DEFAULT 'text'
);

-- Enable real-time
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

### 3. Row Level Security (RLS)
```sql
-- Users can only see discoverable profiles or their friends
CREATE POLICY "Users can view discoverable profiles" ON users
  FOR SELECT USING (is_discoverable = true OR auth.uid() = id);

-- Users can only see messages they sent or received
CREATE POLICY "Users can view their messages" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
```

## Advantages
- Full SQL capabilities
- Better privacy control with RLS
- Real-time subscriptions
- Can be self-hosted