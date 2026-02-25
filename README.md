# 🚀 Boofer - Secure Hybrid Chat App

A privacy-focused, end-to-end encrypted messaging application with hybrid online/offline capabilities.

## 📱 Features

- 🔐 **End-to-End Encryption** - Virgil-style E2EE using X25519 & Ed25519
- 💬 **Secure Messaging** - All messages encrypted before leaving your device
- 👥 **Friend System** - Connect with friends via QR codes or handles
- 📞 **Virtual Numbers** - Privacy-preserving virtual phone numbers
- 🌐 **Multi-Language** - English, German, Spanish, French, Italian
- 🎨 **Customizable** - Multiple themes and appearance options
- 📤 **Share Integration** - Share text and images from other apps
- 🔗 **Deep Linking** - Custom boofer:// URL scheme
- 🔄 **OTA Updates** - Shorebird code push for instant updates
- 🌙 **Dark Mode** - Full dark mode support

## 🏗️ Architecture

### Tech Stack
- **Framework**: Flutter 3.41.2
- **Backend**: Supabase (PostgreSQL + Realtime)
- **Encryption**: libsignal_protocol_dart, cryptography
- **State Management**: Provider
- **Local Storage**: SQLite, FlutterSecureStorage
- **OTA Updates**: Shorebird

### Project Structure
```
lib/
├── core/           - Core functionality & architecture
├── models/         - Data models
├── providers/      - State management
├── screens/        - UI screens
├── services/       - Business logic
├── widgets/        - Reusable components
└── utils/          - Utilities
```

## 🔐 Security Features

- ✅ End-to-end encryption for all messages
- ✅ X25519 key exchange (ECDH)
- ✅ Ed25519 digital signatures
- ✅ AES-256-GCM symmetric encryption
- ✅ Secure key storage (FlutterSecureStorage)
- ✅ Network security config (HTTPS only)
- ✅ Code obfuscation (R8/ProGuard)
- ✅ No cleartext traffic
- ✅ Backup disabled

## 📦 Installation

### Prerequisites
- Flutter SDK 3.10.4+
- Android Studio / Xcode
- Supabase account
- Shorebird CLI (optional, for OTA updates)

### Setup
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Supabase (add your credentials)
4. Run the app:
   ```bash
   flutter run
   ```

## 🔨 Building

### Debug Build
```bash
flutter run
```

### Release Build (Android)
```bash
flutter build appbundle --release
```

### With Shorebird
```bash
shorebird release android
```

## 📄 Documentation

- **[PLAY_STORE_READINESS.md](PLAY_STORE_READINESS.md)** - Complete Play Store submission guide
- **[PRODUCTION_AUDIT_REPORT.md](PRODUCTION_AUDIT_REPORT.md)** - Security audit & code quality report
- **[FILE_LOCATIONS.md](FILE_LOCATIONS.md)** - Important file locations reference

## 🔑 Important Files

### Critical (Backup Required!)
- `android/app/upload-keystore.jks` - Signing keystore
- `android/key.properties` - Keystore credentials

⚠️ **These files are NOT in git. Losing them means you cannot update your app!**

## 🌍 Supported Languages

- 🇬🇧 English
- 🇩🇪 German (Deutsch)
- 🇪🇸 Spanish (Español)
- 🇫🇷 French (Français)
- 🇮🇹 Italian (Italiano)

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

## 📊 Project Status

- **Version**: 1.0.0+1
- **Status**: ✅ Production Ready
- **Build**: ✅ Release build successful (56.8MB AAB)
- **Security**: ✅ Audit passed
- **Code Quality**: ✅ Clean & organized

## 🚀 Deployment

### Play Store Checklist
- ✅ Code is production-ready
- ✅ Security features implemented
- ✅ Build configuration correct
- ⏳ Privacy policy required
- ⏳ Store listing assets needed
- ⏳ Testing on real devices

See [PLAY_STORE_READINESS.md](PLAY_STORE_READINESS.md) for complete checklist.

## 🤝 Contributing

This is a private project. For issues or questions, contact the development team.

## 📜 License

Proprietary - All rights reserved

## 🔒 Privacy

Boofer is built with privacy as a core principle:
- End-to-end encryption for all messages
- No message content stored on servers
- Minimal data collection
- No tracking or analytics (by default)
- User data encrypted at rest

## 📞 Support

For support or questions:
- Check documentation in `/docs`
- Review [PLAY_STORE_READINESS.md](PLAY_STORE_READINESS.md)
- Contact development team

---

**Built with ❤️ using Flutter**  
**Secured with 🔐 End-to-End Encryption**  
**Version**: 1.0.0+1  
**Last Updated**: February 24, 2026
