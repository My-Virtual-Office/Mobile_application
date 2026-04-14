
## 📱 Virtual Office Chat Application

A real-time chat application built with Flutter that integrates with a Spring Boot chat service via WebSocket (STOMP) and REST API. The application supports group channels, direct messages, threads, and push notifications.

---

## 🚀 Features

- **Real-time Messaging**: Send and receive messages instantly using WebSocket (STOMP protocol)
- **Group Channels**: Create and join group channels with multiple members
- **Direct Messages**: Private one-on-one conversations
- **Threads**: Create threads from messages for organized discussions
- **Read Receipts**: Track unread messages in channels and threads
- **Typing Indicators**: See when other users are typing
- **Message Management**: Edit and delete your own messages (Admins can delete any non-admin messages)
- **Push Notifications**: Receive notifications even when the app is in background or terminated
- **User Roles**: Support for USER and ADMIN roles with different permissions

---

## 🛠️ Tech Stack & Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| **Flutter** | 3.x | UI Framework |
| **Provider** | ^6.1.2 | State Management |
| **Stomp Dart Client** | ^1.0.2 | WebSocket (STOMP protocol) communication |
| **HTTP** | ^1.2.1 | REST API calls |
| **Shared Preferences** | ^2.2.3 | Local storage for connection settings |
| **UUID** | ^4.3.3 | Generate unique client message IDs |
| **Awesome Notifications** | ^0.9.3+1 | Push notifications (foreground/background/terminated) |

### Why these libraries?

- **Provider**: Simple and efficient state management without boilerplate code
- **Stomp Dart Client**: Reliable WebSocket implementation with STOMP protocol support for message queuing
- **HTTP**: Lightweight and widely used for REST API calls
- **Shared Preferences**: Simple key-value storage for persisting user connection settings
- **UUID**: Ensures idempotent message sending to prevent duplicates
- **Awesome Notifications**: Cross-platform notifications that work even when the app is terminated

---

## 📐 Architecture

```
lib/
├── core/
│   ├── constants/        # App constants and configurations
│   ├── services/         # Notification service
│   └── theme/           # App theming
├── features/
│   └── chat/
│       ├── api/          # REST API client
│       ├── models/       # Data models (Channel, Message, Thread, etc.)
│       ├── providers/    # State management (MessageProvider, ChannelProvider, etc.)
│       ├── repositories/ # Data layer (ChatRepository)
│       ├── screens/      # UI screens (ChatScreen, ChannelsScreen, etc.)
│       ├── services/     # WebSocket service (STOMP)
│       └── widgets/      # Reusable chat widgets (MessageBubble, ChatComposer, etc.)
```

### Data Flow

```
User Action → Provider → Repository → API/WebSocket → Server
                    ↓
              State Update → UI Rebuild
```

---

## 🔧 Setup & Installation

### Prerequisites

- Flutter SDK (3.x or higher)
- Java 21+ (for backend service)
- Docker (for MongoDB and Redis)

### Backend Setup

```bash
# Clone the backend repository
cd backend/chat-service

# Start MongoDB and Redis
docker compose up -d

# Run the Spring Boot application
./mvnw spring-boot:run
```

The backend will start on `http://localhost:8084`

### Frontend Setup

```bash
# Clone the repository
git clone <https://github.com/My-Virtual-Office/Mobile_application.git>
cd virtual_office

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Android Configuration

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## 🔌 Connection Guide

1. **Start the backend service** on your machine
2. **Find your machine's IP address**:
   ```bash
   ip addr show | grep "inet " | grep -v 127.0.0.1
   ```
3. **Open the app** and enter:
   - **HTTP URL**: `http://<YOUR_IP>:8084`
   - **WebSocket URL**: `ws://<YOUR_IP>:8084`
   - **User ID**: Any integer (e.g., 1, 2, 3)
   - **Role**: `USER` or `ADMIN`

> **For Android Emulator**: Use `http://10.0.2.2:8084` and `ws://10.0.2.2:8084`

---

## 📡 API Integration

### REST Endpoints Used

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/chat/health` | Health check |
| POST | `/api/chat/ws-ticket` | Get WebSocket ticket |
| GET | `/api/chat/channels` | List channels |
| POST | `/api/chat/channels` | Create channel |
| POST | `/api/chat/channels/{id}/join` | Join channel |
| POST | `/api/chat/channels/{id}/leave` | Leave channel |
| POST | `/api/chat/dm` | Create/get DM |
| GET | `/api/chat/channels/{id}/messages` | Get messages |
| POST | `/api/chat/channels/{id}/messages` | Send message |
| PUT | `/api/chat/messages/{id}` | Edit message |
| DELETE | `/api/chat/messages/{id}` | Delete message |
| POST | `/api/chat/channels/{id}/threads` | Create thread |
| GET | `/api/chat/channels/{id}/threads` | List threads |
| POST | `/api/chat/channels/{id}/read` | Mark as read |
| GET | `/api/chat/channels/{id}/unread` | Get unread count |

### WebSocket (STOMP) Topics

| Topic | Purpose |
|-------|---------|
| `/topic/channel/{channelId}` | Channel messages |
| `/topic/thread/{threadId}` | Thread messages |
| `/topic/channel/{channelId}/typing` | Typing indicators |
| `/app/chat/send` | Send message |
| `/app/chat/typing` | Send typing event |
| `/user/queue/errors` | Personal error queue |

---

## 🎯 Key Implementation Details

### 1. Real-time Messaging
- Uses STOMP over WebSocket for bidirectional communication
- Optimistic updates for better UX (message appears immediately)
- Automatic fallback to REST API if WebSocket fails

### 2. Message Synchronization
- Messages are stored in `ChatRepository` with a Map keyed by channel/thread ID
- WebSocket events (`NEW_MESSAGE`, `EDIT_MESSAGE`, `DELETE_MESSAGE`) update the local state
- All providers listen to repository streams for real-time updates

### 3. Offline Support
- Messages are cached in memory while the app is running
- When WebSocket reconnects, `catchUpChannelMessages` loads missed messages

### 4. Push Notifications
- Implemented with `awesome_notifications`
- Works in foreground, background, and terminated states
- Different channels for messages, DMs, and threads
- System notifications for channel invites

### 5. Permission System
- **USER**: Can edit/delete own messages, cannot delete others
- **ADMIN**: Can delete any non-admin user's messages, cannot edit others

### 6. Read Receipts
- Each channel and thread tracks the last read message
- Unread counts are fetched when loading channel lists
- Mark as read when leaving a channel/thread

---

## 🧪 Testing

### Manual Testing

1. **Open two instances** of the app (different user IDs)
2. **Create a channel** and add both users
3. **Send messages** between users
4. **Create a thread** from a message
5. **Test notifications** by putting the app in background
6. **Test permissions** with USER and ADMIN roles

### Connection Testing

```bash
# Test REST API
curl http://192.168.8.65:8084/api/chat/health

# Test WebSocket (using wscat)
npm install -g wscat
wscat -c ws://192.168.8.65:8084/api/chat/connect?ticket=YOUR_TICKET
```

---

## 🐛 Troubleshooting

### Connection Issues

| Problem | Solution |
|---------|----------|
| "No route to host" | Check if devices are on same network |
| "Connection refused" | Verify backend is running on the correct port |
| "WebSocket upgrade failed" | Use HTTP URL for SockJS or ensure ws:// is correct |

### Notification Issues

| Problem | Solution |
|---------|----------|
| Notifications not showing | Check permissions in Android/iOS settings |
| Notifications in background | Add `wakeUpScreen: true` to notification content |
| Channel not found | Restart app to recreate notification channels |

### Message Issues

| Problem | Solution |
|---------|----------|
| Messages not appearing | Check WebSocket connection status |
| Duplicate messages | Verify clientMessageId is being set properly |
| Messages disappear on exit | Messages are cached in memory; reload from API on re-entry |

---

## 📱 Screens

1. **ConnectionScreen** - Enter server details and user credentials
2. **HomeScreen** - Navigate to Channels or Direct Messages
3. **ChannelsScreen** - List of group channels with unread counts
4. **DMsScreen** - List of direct message conversations
5. **ChatScreen** - Main chat interface with message bubbles
6. **ThreadsListScreen** - List of threads in a channel
7. **ThreadScreen** - Thread messages interface

---

## 🔐 Authentication

The application uses header-based authentication (no JWT):

- `X-User-Id`: User ID (integer)
- `X-User-Role`: `USER` or `ADMIN`

These headers are automatically added to every REST request.

---

---

## 👨‍💻 Author

Built with Flutter and Spring Boot for real-time communication.

---

## 🙏 Acknowledgments

- Spring Boot Chat Service for the backend API
- STOMP protocol for WebSocket messaging
- Flutter community for excellent packages