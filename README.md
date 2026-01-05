# Boofer Chat

A privacy-first Flutter chat application with hybrid online/offline messaging capabilities and comprehensive theme switching.

## Features

### 🎨 Theme Switching
- **Complete dark/light theme support** across the entire app
- **Persistent theme preferences** using SharedPreferences
- **Multiple theme toggle options**:
  - Icon buttons in app bars
  - Toggle switches with visual indicators
  - Theme cards for settings screens
  - Floating action buttons
- **Automatic theme persistence** - your choice is remembered between app sessions
- **Smooth theme transitions** with Material 3 design

### 💬 Chat Features
- Hybrid online/offline messaging
- Mesh networking capabilities
- Privacy-first approach with virtual numbers
- Real-time message synchronization

## Theme Implementation

The app uses a comprehensive theme system built with:

- **ThemeProvider**: State management for theme switching using Provider pattern
- **Custom Theme Widgets**: Reusable components for consistent theme controls
- **Material 3 Design**: Modern color schemes and components
- **Persistent Storage**: Theme preferences saved locally

### Theme Toggle Components

1. **ThemeToggleButton**: Simple icon button for app bars
2. **ThemeToggleSwitch**: Switch with light/dark mode icons
3. **ThemeToggleCard**: Card-style toggle for settings screens

### Usage Example

```dart
// Add to your app's main widget
ChangeNotifierProvider(
  create: (context) => ThemeProvider(),
  child: Consumer<ThemeProvider>(
    builder: (context, themeProvider, child) {
      return MaterialApp(
        theme: themeProvider.lightTheme,
        darkTheme: themeProvider.darkTheme,
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        // ... rest of your app
      );
    },
  ),
)

// Add theme toggle anywhere in your app
ThemeToggleButton()
```

## Getting Started

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

### Available Entry Points

- `lib/main.dart` - Full-featured app with service initialization
- `lib/main_simple.dart` - Simple demo with theme switching
- `lib/main_demo.dart` - Demo with onboarding flow

## Project Structure

```
lib/
├── main.dart                 # Main app entry point
├── main_simple.dart         # Simple demo version
├── main_demo.dart          # Demo with onboarding
├── providers/
│   └── theme_provider.dart  # Theme state management
├── widgets/
│   └── theme_toggle_button.dart  # Theme toggle components
├── screens/
│   ├── chat_screen.dart     # Main chat interface
│   ├── settings_screen.dart # Settings with theme demo
│   └── ...                  # Other screens
└── services/               # App services and utilities
```

## Theme Customization

The theme system supports easy customization:

1. **Colors**: Modify the color schemes in `ThemeProvider`
2. **Components**: Customize Material 3 component themes
3. **Typography**: Adjust text styles and fonts
4. **Animations**: Add custom theme transition animations

## Dependencies

- `flutter`: SDK
- `provider`: State management for theme switching
- `shared_preferences`: Persistent theme storage
- `material3`: Modern design components

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test theme switching across all screens
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
