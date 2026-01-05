import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boofer/widgets/connection_status.dart';
import 'package:boofer/models/message_model.dart';

void main() {
  group('ConnectionStatus Widget Tests', () {
    testWidgets('displays online status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: true,
              isOfflineMode: false,
              peerCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });

    testWidgets('displays offline status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 3,
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('displays peer count in offline mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 5,
            ),
          ),
        ),
      );

      expect(find.text('5 peers'), findsOneWidget);
    });

    testWidgets('displays zero peers correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('0 peers'), findsOneWidget);
    });

    testWidgets('displays singular peer correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 1,
            ),
          ),
        ),
      );

      expect(find.text('1 peer'), findsOneWidget);
    });

    testWidgets('shows correct color for online status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: true,
              isOfflineMode: false,
              peerCount: 0,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });

    testWidgets('shows correct color for offline status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 0,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.orange);
    });

    testWidgets('shows correct color for disconnected status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: false,
              peerCount: 0,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.red);
    });

    testWidgets('displays mesh mode indicator when in offline mode with peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 3,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.device_hub), findsOneWidget);
    });

    testWidgets('does not display mesh indicator when no peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.device_hub), findsNothing);
    });

    testWidgets('updates when connection state changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: false,
              isOfflineMode: true,
              peerCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);

      // Update to online
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatus(
              isOnline: true,
              isOfflineMode: false,
              peerCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
    });
  });
}