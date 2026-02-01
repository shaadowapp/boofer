# Custom Backend Plan for Boofer

## Why Custom Backend?
- Full control over privacy and data
- Custom business logic
- Can implement mesh networking features
- No vendor lock-in

## Tech Stack
- **Backend**: Node.js + Express + TypeScript
- **Database**: PostgreSQL + Redis (caching)
- **Real-time**: Socket.IO or WebSockets
- **Authentication**: JWT tokens
- **Deployment**: Docker + AWS/DigitalOcean

## API Structure

### Authentication Endpoints
```
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
```

### User Management
```
GET /api/users/profile
PUT /api/users/profile
GET /api/users/search?q=username
GET /api/users/discover
```

### Messaging
```
GET /api/conversations
GET /api/conversations/:id/messages
POST /api/conversations/:id/messages
WebSocket: /ws/chat
```

### Friend System
```
POST /api/connections/request
GET /api/connections/requests
PUT /api/connections/requests/:id/accept
PUT /api/connections/requests/:id/decline
```

## Implementation Steps

### 1. Backend Setup
```bash
mkdir boofer-backend
cd boofer-backend
npm init -y
npm install express typescript socket.io pg redis jsonwebtoken bcrypt
npm install -D @types/node @types/express nodemon
```

### 2. Flutter HTTP Client
```yaml
dependencies:
  http: ^1.1.0
  socket_io_client: ^2.0.3+1
```

### 3. Sync Service Architecture
- Implement queue system for offline messages
- Background sync when connection restored
- Conflict resolution for simultaneous edits