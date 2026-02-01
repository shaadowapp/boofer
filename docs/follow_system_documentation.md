# Friend Request System Documentation (Instagram/Snapchat Style)

## Overview

The friend request system implements a comprehensive social networking feature similar to Instagram and Snapchat, where users must send friend requests and get approval before they can message each other. This ensures privacy and prevents spam messaging.

## Key Features

### 🔐 Privacy-First Design
- **No messaging without friendship** - Only friends can message each other
- **Request-based system** - Users must send and accept friend requests
- **Mutual consent** - Both parties must agree to be friends

### 📱 Instagram/Snapchat-like Flow
1. **Send Friend Request** → Creates pending request with optional message
2. **Receive Notification** → Shows in "Friend Requests" screen
3. **Accept/Reject** → Becomes friends or gets rejected
4. **Sent Requests Tracking** → View and cancel outgoing requests
5. **Friends Management** - View friends list and unfriend users

## Architecture

### Data Model

```
friend_requests/{requestId}                    - Individual friend requests
users/{userId}/sent_requests/{requestId}       - Outgoing requests (user's perspective)
users/{userId}/received_requests/{requestId}   - Incoming requests (user's perspective)
friends/{userId}/friends/{friendId}            - Mutual friendships
users/{userId}                                 - User document with friend counts
```

### Request States

```dart
enum FriendRequestStatus {
  pending,    // Request sent, awaiting response
  accepted,   // Request accepted, users are now friends
  rejected,   // Request rejected
  cancelled,  // Request cancelled by sender
}
```

## Core Components

### 1. FriendRequestService
Core business logic handling all friend request operations with atomic transactions.

### 2. FriendRequestProvider
State management with ChangeNotifier for real-time UI updates.

### 3. FriendRequestButton
Smart button component that shows appropriate action based on relationship status.

### 4. FriendRequestsScreen
Tabbed interface showing received and sent requests (like Instagram).

## Usage Examples

### Initialize Friend Request System

```dart
// In your main app
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => FriendRequestProvider()),
    // ... other providers
  ],
  child: MyApp(),
)

// Initialize with current user
await context.read<FriendRequestProvider>().initialize(currentUserId);
```

### Friend Request Button

```dart
FriendRequestButton(
  user: targetUser,
  onStatusChanged: () {
    // Handle status change
  },
  compact: false, // or true for icon-only button
)
```

### Check Relationship Status

```dart
final provider = context.read<FriendRequestProvider>();

// Check if users are friends
final areFriends = provider.areFriends(userId);

// Check if user can message another user
final canMessage = provider.canMessage(userId);

// Get relationship status for UI
final status = provider.getRelationshipStatus(userId);
// Returns: 'friends', 'request_sent', 'request_received', 'none', etc.
```

### Friend Request Stats Widget

```dart
FriendRequestStatsWidget(
  onFriendsPressed: () {
    // Navigate to friends list
  },
  onRequestsPressed: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const FriendRequestsScreen(),
    ));
  },
)
```

## API Reference

### FriendRequestService Methods

#### Core Operations

```dart
// Send friend request
Future<bool> sendFriendRequest({
  required String fromUserId,
  required String toUserId,
  String? message,
});

// Accept friend request
Future<bool> acceptFriendRequest({
  required String requestId,
  required String userId,
});

// Reject friend request
Future<bool> rejectFriendRequest({
  required String requestId,
  required String userId,
});

// Cancel sent request
Future<bool> cancelFriendRequest({
  required String requestId,
  required String userId,
});
```

#### Status Checking

```dart
// Check if users are friends
Future<bool> areFriends({
  required String userId1,
  required String userId2,
});

// Get friend request status
Future<FriendRequest?> getFriendRequestStatus({
  required String fromUserId,
  required String toUserId,
});
```

#### Data Retrieval

```dart
// Get received requests (pending)
Future<List<FriendRequest>> getReceivedFriendRequests({
  required String userId,
  int limit = 20,
});

// Get sent requests (pending)
Future<List<FriendRequest>> getSentFriendRequests({
  required String userId,
  int limit = 20,
});

// Get friends list
Future<List<User>> getFriends({
  required String userId,
  int limit = 50,
});

// Get friend request statistics
Future<FriendRequestStats> getFriendRequestStats(String userId);
```

#### Friend Management

```dart
// Remove friend (unfriend)
Future<bool> removeFriend({
  required String userId,
  required String friendId,
});
```

### FriendRequestProvider Methods

```dart
// Initialize provider
Future<void> initialize(String userId);

// Send friend request with message
Future<bool> sendFriendRequest(String userId, {String? message});

// Accept/reject/cancel requests
Future<bool> acceptFriendRequest(String requestId);
Future<bool> rejectFriendRequest(String requestId);
Future<bool> cancelFriendRequest(String requestId);

// Friend management
Future<bool> removeFriend(String friendId);

// Status checking
bool areFriends(String userId);
bool canMessage(String userId);
String getRelationshipStatus(String userId);
FriendRequest? getFriendRequestStatus(String userId);

// Data loading
Future<void> loadReceivedRequests({bool refresh = false});
Future<void> loadSentRequests({bool refresh = false});
Future<void> loadFriends({bool refresh = false});
Future<void> checkFriendshipStatus(List<String> userIds);
```

## UI Components

### Relationship Status Display

The `FriendRequestButton` automatically shows the appropriate state:

- **"Add Friend"** - No relationship, can send request
- **"Pending"** - Request sent, waiting for response
- **"Accept"** - Received request, can accept
- **"Friends"** - Already friends, can unfriend

### Friend Requests Screen

Tabbed interface similar to Instagram:

- **Received Tab** - Incoming requests with Accept/Reject buttons
- **Sent Tab** - Outgoing requests with Cancel option
- **Badge indicators** - Show count of pending requests

## Security & Privacy

### Firestore Security Rules

```javascript
// Users can only read/write their own requests
match /friend_requests/{requestId} {
  allow read: if request.auth.uid == resource.data.fromUserId 
              || request.auth.uid == resource.data.toUserId;
  allow create: if request.auth.uid == resource.data.fromUserId;
  allow update: if canRespondToRequest() || canCancelRequest();
}
```

### Privacy Features

- **Request validation** - Users can't send requests to themselves
- **Duplicate prevention** - Can't send multiple requests to same user
- **Message encryption** - Only friends can message each other
- **Block functionality** - Can remove friends to stop communication

## Real-time Updates

The system provides real-time synchronization:

```dart
// Listen to received requests
_subscriptions['received'] = service.listenToReceivedRequests(userId)?.listen(
  (requests) {
    // Update UI with new requests
  },
);

// Listen to friend count changes
_subscriptions['stats'] = service.listenToStats(userId)?.listen(
  (stats) {
    // Update friend counts in real-time
  },
);
```

## Integration with Messaging

### Message Permission Check

```dart
// Before allowing message sending
final provider = context.read<FriendRequestProvider>();
if (!provider.canMessage(recipientId)) {
  // Show "Send friend request first" dialog
  return;
}

// Proceed with message sending
await sendMessage(recipientId, messageText);
```

### Profile Screen Integration

```dart
// In user profile screen
Widget build(BuildContext context) {
  return Column(
    children: [
      // User info
      UserProfileCard(user: user),
      
      // Friend request button
      FriendRequestButton(
        user: user,
        onStatusChanged: () {
          // Refresh profile data
        },
      ),
      
      // Message button (only show if friends)
      Consumer<FriendRequestProvider>(
        builder: (context, provider, child) {
          if (provider.canMessage(user.id)) {
            return ElevatedButton(
              onPressed: () => _openChat(user),
              child: const Text('Message'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ],
  );
}
```

## Error Handling

### Common Scenarios

```dart
try {
  final success = await provider.sendFriendRequest(userId);
  if (!success) {
    // Handle specific errors
    switch (provider.error) {
      case 'Already friends':
        showSnackBar('You are already friends with this user');
        break;
      case 'Request already sent':
        showSnackBar('Friend request already sent');
        break;
      default:
        showSnackBar('Failed to send friend request');
    }
  }
} catch (e) {
  showSnackBar('Network error: Please try again');
}
```

## Performance Optimizations

### Efficient Queries

- **Indexed queries** - Proper Firestore indexes for fast lookups
- **Pagination** - Load requests in batches
- **Caching** - Provider caches frequently accessed data
- **Batch operations** - Check multiple friendship statuses at once

### Memory Management

```dart
@override
void dispose() {
  // Cancel all real-time listeners
  for (final subscription in _subscriptions.values) {
    subscription.cancel();
  }
  super.dispose();
}
```

## Testing

### Unit Tests

```dart
test('should send friend request successfully', () async {
  final result = await friendRequestService.sendFriendRequest(
    fromUserId: 'user1',
    toUserId: 'user2',
    message: 'Hi there!',
  );
  expect(result, true);
});

test('should prevent duplicate requests', () async {
  // Send first request
  await friendRequestService.sendFriendRequest(
    fromUserId: 'user1',
    toUserId: 'user2',
  );
  
  // Try to send again
  final result = await friendRequestService.sendFriendRequest(
    fromUserId: 'user1',
    toUserId: 'user2',
  );
  expect(result, false);
});
```

### Widget Tests

```dart
testWidgets('should show correct button state', (tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FriendRequestProvider(),
      child: MaterialApp(
        home: FriendRequestButton(user: testUser),
      ),
    ),
  );
  
  expect(find.text('Add Friend'), findsOneWidget);
});
```

## Migration from Follow System

### Data Migration

```dart
// Migrate existing follow relationships to friendships
Future<void> migrateFollowsToFriends() async {
  final batch = FirebaseFirestore.instance.batch();
  
  // Get all mutual follows
  final mutualFollows = await getMutualFollows();
  
  for (final relationship in mutualFollows) {
    // Create friendship documents
    batch.set(
      FirebaseFirestore.instance
          .collection('friends')
          .doc(relationship.user1)
          .collection('friends')
          .doc(relationship.user2),
      {
        'userId': relationship.user2,
        'friendsSince': DateTime.now().toIso8601String(),
        'migratedFrom': 'follow_system',
      },
    );
  }
  
  await batch.commit();
}
```

## Best Practices

### Development

1. **Always check friendship status** before allowing messaging
2. **Use atomic transactions** for all friend request operations
3. **Implement optimistic updates** for better UX
4. **Handle edge cases** (self-requests, duplicates, etc.)
5. **Provide clear feedback** for all user actions

### Production

1. **Monitor request patterns** for spam detection
2. **Set rate limits** on friend request sending
3. **Implement proper indexes** for query performance
4. **Regular cleanup** of old rejected/cancelled requests
5. **Analytics tracking** for user engagement metrics

## Troubleshooting

### Common Issues

1. **"Can't send message"** - Check if users are friends
2. **Requests not appearing** - Verify real-time listeners are active
3. **Duplicate requests** - Check transaction logic
4. **Permission denied** - Review Firestore security rules
5. **Slow queries** - Ensure proper indexing

### Debug Tools

```dart
// Enable debug logging
FriendRequestService.instance.enableDebugLogging = true;

// Check relationship status
final status = await service.getFriendRequestStatus(
  fromUserId: 'user1',
  toUserId: 'user2',
);
print('Request status: $status');
```

This friend request system provides a complete Instagram/Snapchat-like experience with proper privacy controls, real-time updates, and comprehensive error handling.