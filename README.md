# Boofer Chat

A privacy-first Flutter chat application that combines WhatsApp's familiar messaging interface with Snapchat's global social discovery features. Connect with anyone in the world using virtual phone numbers and usernames.

## 🌟 Core Concept

Boofer is the perfect blend of:
- **WhatsApp's UI**: Clean, familiar messaging interface that users already know and love
- **Snapchat's Social Discovery**: Find and connect with people globally without sharing personal information
- **Privacy-First Approach**: Virtual phone numbers and usernames keep your real identity completely private

## ✨ Key Features

### 🔐 Privacy & Security
- **Virtual Phone Numbers**: No real phone number required - get assigned a unique virtual number
- **Username System**: Create a unique username for easy discovery (e.g., @Alex_NYC, @Sarah_London)
- **Complete Anonymity**: Your real identity stays private until you choose to share it
- **No Personal Data**: No email, real name, or location data required to sign up

### 🌍 Global Social Discovery
- **Search Globally**: Find people by username or virtual number from anywhere in the world
- **Nearby Discovery**: Connect with people around you (optional, privacy-controlled)
- **Interest-Based Suggestions**: Get matched with people who share similar interests
- **Connection Requests**: Send and receive connection requests before starting conversations

### 💬 WhatsApp-Style Messaging
- **Familiar Interface**: Clean, intuitive chat interface similar to WhatsApp
- **Real-time Messaging**: Instant message delivery and read receipts
- **Group Chats**: Create and manage group conversations
- **Media Sharing**: Send photos, videos, and files (coming soon)
- **Voice & Video Calls**: High-quality calling features (coming soon)

### 🎨 Modern Design
- **Material 3 Design**: Beautiful, modern interface with smooth animations
- **Dark/Light Themes**: Complete theme support with automatic persistence
- **Responsive Layout**: Works perfectly on all screen sizes
- **Accessibility**: Full accessibility support for all users

## 🚀 How It Works

1. **Sign Up**: Get assigned a virtual phone number and create a unique username
2. **Discover**: Search for people globally or find nearby users
3. **Connect**: Send connection requests to start conversations
4. **Chat**: Enjoy familiar WhatsApp-style messaging with complete privacy

## 📱 Screenshots & Demo

### Discovery Features
- Global user search by username or virtual number
- Nearby people discovery (location-based, optional)
- Interest-based user suggestions
- Connection request system

### Messaging Features  
- WhatsApp-style chat interface
- Real-time message delivery
- Read receipts and online status
- Archive and mute conversations

## 🛠 Technical Features

### Architecture
- **Flutter**: Cross-platform mobile development
- **Provider**: State management for reactive UI updates
- **Material 3**: Modern design system implementation
- **Hybrid Messaging**: Online/offline message synchronization (coming soon)

### Privacy Implementation
- **Virtual Numbers**: Randomly generated, unique identifiers
- **Username System**: User-chosen, globally unique handles
- **No Data Collection**: Minimal data storage, maximum privacy
- **Local Storage**: Messages and data stored locally on device

## 🎯 Target Audience

Perfect for users who want:
- **Global Connections**: Meet people from different countries and cultures
- **Privacy Protection**: Chat without revealing personal information
- **Familiar Experience**: WhatsApp-like interface they already know
- **Social Discovery**: Snapchat-style ability to find new people
- **Safe Environment**: Controlled connections through request system

## 🔮 Upcoming Features

### Phase 1 (Current)
- ✅ Virtual phone numbers and usernames
- ✅ Global user search and discovery
- ✅ Connection request system
- ✅ WhatsApp-style messaging interface
- ✅ Theme switching and modern UI

### Phase 2 (Coming Soon)
- 📸 Photo and video sharing
- 🎥 Voice and video calls
- 👥 Group chat creation and management
- 🌐 Multi-language support
- 🔔 Push notifications

### Phase 3 (Future)
- 📱 Stories/Status updates (Snapchat-style)
- 🎮 Interactive features and games
- 🤖 AI-powered user matching
- 🔒 End-to-end encryption
- ☁️ Cloud backup (optional)

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.10.4 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd boofer
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### First Launch
1. The app will generate a virtual phone number for you
2. Create your unique username (e.g., Alex_NYC)
3. Set up your profile (optional display name and bio)
4. Start discovering and connecting with people worldwide!

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── friend_model.dart       # Chat/friend data model
│   ├── user_model.dart         # User profile model
│   └── message_model.dart      # Message data model
├── screens/
│   ├── main_screen.dart        # Main navigation (WhatsApp-style)
│   ├── home_screen.dart        # Discovery hub (Snapchat-style)
│   ├── lobby_screen.dart       # Chat list (WhatsApp-style)
│   ├── global_search_screen.dart # Global user search
│   ├── connection_requests_screen.dart # Manage connections
│   └── chat_screen.dart        # Individual chat interface
├── services/
│   ├── user_service.dart       # User profile management
│   ├── connection_service.dart # Social discovery features
│   └── messaging_service.dart  # Chat functionality
├── providers/
│   ├── theme_provider.dart     # Theme management
│   ├── chat_provider.dart      # Chat state management
│   └── user_provider.dart      # User state management
└── widgets/
    ├── theme_toggle_button.dart # Theme switching components
    └── chat_widgets.dart       # Reusable chat UI components
```

## 🎨 Design Philosophy

### WhatsApp Inspiration
- **Familiar Navigation**: Bottom tabs for Chats, Calls, and Settings
- **Clean Chat Interface**: Message bubbles, timestamps, and read receipts
- **Contact Management**: Easy friend/contact organization
- **Intuitive UX**: Users feel at home immediately

### Snapchat Innovation
- **Global Discovery**: Find anyone, anywhere in the world
- **Username Culture**: Unique handles for easy identification
- **Social Exploration**: Discover new people and cultures
- **Privacy by Design**: Connect safely without personal data

### Modern Mobile Design
- **Material 3**: Latest design guidelines and components
- **Smooth Animations**: Delightful micro-interactions
- **Responsive Layout**: Perfect on all screen sizes
- **Accessibility First**: Inclusive design for all users

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Feature Development**: Implement new discovery or messaging features
2. **UI/UX Improvements**: Enhance the WhatsApp/Snapchat-inspired interface
3. **Privacy Features**: Strengthen anonymity and security measures
4. **Performance**: Optimize for better speed and efficiency
5. **Testing**: Help test across different devices and scenarios

### Development Guidelines
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow Flutter best practices and Material 3 design
4. Test thoroughly on both Android and iOS
5. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🌟 Why Boofer?

In a world where privacy is increasingly important, Boofer offers a unique solution:

- **Global Connections**: Meet people from different cultures and backgrounds
- **Complete Privacy**: No personal information required or stored
- **Familiar Experience**: Interface users already know and love
- **Safe Discovery**: Controlled connections through request system
- **Modern Design**: Beautiful, accessible, and responsive interface

Join the Boofer community and start connecting with the world while keeping your privacy intact! 🚀
