# Friend-Only Messaging System

This document describes the enhanced friend-only messaging and calling system implemented in your Boofer app.

## Overview

The system ensures that users can only send messages and make calls to people they are friends with. This provides privacy and security by preventing unwanted communications.

## Key Features

### 1. Friendship Management
- **Friend Requests**: Users can send, receive, accept, and decline friend requests
- **Friend Status**: Real-time tracking of friendship status between users
- **Friend List**: Dedicated screen to view and manage friends

### 2. Friend-Only Communication
- **Messaging**: Users can only send messages to friends
- **Calling**: Users can only call friends
- **Conversation Access**: Only friends can access shared conversations

### 3. User Interface
- **Friends Tab**: New tab in the main navigation for managing friends
- **Search Screen**: Find and add new friends
- **Friend Requests Screen**: Manage incoming and outgoing friend requests
- **Friendship Status Widget**: Shows current relationship status with actions

## File Structure

### Services
- `lib/services/friendship_service.dart` - Core friendship management logic
- `lib/services/chat_service.dart` - Enhanced with friend validation

### Screens
- `lib/screens/friends_screen.dart` - Main friends list
- `lib/screens/friend_requests_screen.dart` - Manage friend requests
- `lib/screens/user_search_screen.dart` - Find and add friends
- `lib/screens/friend_chat_screen.dart` - Friend-only chat interface

### Widgets
- `lib/widgets/friendship_status_widget.dart` - Shows friendship status and actions
- `lib/widgets/friend_only_message_widget.dart` - Displayed when trying to message non-friends

## How It Works

### Friendship Status
The system tracks five friendship states:
- `none` - No relationship exists
- `requestSent` - Current user sent a friend request
- `requestReceived` - Current user received a friend request
- `friends` - Users are friends (can communicate)
- `blocked` - One user blocked the other

### Message Validation
Before sending any message, the system:
1. Checks if sender and receiver are friends
2. Validates conversation access
3. Blocks the message if users aren't friends
4. Shows appropriate UI feedback

### Call Validation
Before initiating any call, the system:
1. Verifies friendship status
2. Prevents calls to non-friends
3. Shows error messages for unauthorized calls

## User Experience

### Adding Friends
1. Navigate to the Friends tab
2. Tap the "Find Friends" button or use the search icon in the app bar
3. Search for users by username or display name
4. Send friend requests to desired users

### Managing Friend Requests
1. Tap the friend request icon in the app bar (shows badge with count)
2. View received and sent requests in separate tabs
3. Accept or decline incoming requests
4. Monitor status of sent requests

### Messaging Friends
1. Go to the Friends tab
2. Tap on a friend to open chat
3. Send messages normally
4. If trying to message a non-friend, see the friend-only screen with option to send request

### Privacy Protection
- Users cannot message or call non-friends
- Conversation access is restricted to friends only
- Clear UI feedback when actions are blocked
- Easy friend request process to establish connections

## Integration

The friend system is integrated into the main app navigation:
- **Friends Tab**: New tab between Chats and Calls
- **App Bar Actions**: Friend requests and search buttons
- **FAB Actions**: Add friends when on Friends tab
- **Search Integration**: Find friends functionality

## Database Schema

The system uses existing tables:
- `friends` - Stores accepted friendships
- `connection_requests` - Manages friend requests and their status
- `messages` - Enhanced with friendship validation

## Security Features

1. **Access Control**: Only friends can access conversations
2. **Request Validation**: Prevents duplicate or invalid friend requests
3. **Status Tracking**: Real-time friendship status updates
4. **Privacy First**: Default deny for all communications

## Future Enhancements

Potential improvements:
- Block/unblock functionality
- Friend suggestions based on mutual connections
- Group chats with friend validation
- Enhanced privacy settings
- Friend categories/groups

## Usage Tips

1. **Start by adding friends** - Use the search feature to find people you know
2. **Check friend requests regularly** - Use the badge indicator in the app bar
3. **Manage your friends list** - Remove friends you no longer want to communicate with
4. **Respect privacy** - The system is designed to prevent unwanted communications

This friend-only system provides a secure and user-friendly way to manage communications while maintaining privacy and preventing spam or unwanted messages.