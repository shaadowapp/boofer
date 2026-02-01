# Firebase Integration Plan for Boofer

## Why Firebase?
- Real-time messaging with Firestore
- Built-in authentication
- Cloud Functions for server logic
- Easy Flutter integration
- Scalable and managed

## Implementation Steps

### 1. Add Firebase Dependencies
```yaml
dependencies:
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_auth: ^4.15.3
  firebase_messaging: ^14.7.10
  firebase_storage: ^11.5.6
```

### 2. Database Structure in Firestore

#### Collections:
- `users/` - User profiles and virtual numbers
- `conversations/` - Chat metadata
- `messages/` - Real-time messages
- `connection_requests/` - Friend requests
- `user_discovery/` - Global user search index

### 3. Hybrid Architecture
- Keep SQLite for offline storage and caching
- Sync with Firestore for real-time features
- Implement offline-first approach

### 4. Key Services to Modify
- `ChatService` - Add Firestore real-time listeners
- `UserService` - Sync with Firebase Auth
- `ConnectionService` - Real-time friend requests
- Add `SyncService` for offline/online data sync

## Security Features
- Firestore security rules for privacy
- Virtual number generation on server
- Message encryption before storage