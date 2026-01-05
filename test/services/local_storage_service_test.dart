import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boofer/services/local_storage_service.dart';

import 'local_storage_service_test.mocks.dart';

@GenerateMocks([SharedPreferences, FlutterSecureStorage])
void main() {
  group('LocalStorageService', () {
    late LocalStorageService service;
    late MockSharedPreferences mockPrefs;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      mockSecureStorage = MockFlutterSecureStorage();
      service = LocalStorageService(
        prefs: mockPrefs,
        secureStorage: mockSecureStorage,
      );
    });

    group('onboarding data management', () {
      test('should save onboarding data successfully', () async {
        // Arrange
        final testData = {
          'userName': 'John Doe',
          'virtualNumber': '+1234567890',
          'termsAccepted': true,
          'currentStep': 2,
          'isComplete': false,
        };

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        await service.saveOnboardingData(testData);

        // Assert
        verify(mockPrefs.setString('onboarding_data', any)).called(1);
      });

      test('should load onboarding data successfully', () async {
        // Arrange
        const jsonData = '''
        {
          "userName": "John Doe",
          "virtualNumber": "+1234567890",
          "termsAccepted": true,
          "currentStep": 2,
          "isComplete": false
        }
        ''';

        when(mockPrefs.getString('onboarding_data')).thenReturn(jsonData);

        // Act
        final result = await service.getOnboardingData();

        // Assert
        expect(result, isNotNull);
        expect(result!['userName'], equals('John Doe'));
        expect(result['virtualNumber'], equals('+1234567890'));
        expect(result['termsAccepted'], equals(true));
        expect(result['currentStep'], equals(2));
        expect(result['isComplete'], equals(false));
        verify(mockPrefs.getString('onboarding_data')).called(1);
      });

      test('should return null when no onboarding data exists', () async {
        // Arrange
        when(mockPrefs.getString('onboarding_data')).thenReturn(null);

        // Act
        final result = await service.getOnboardingData();

        // Assert
        expect(result, isNull);
        verify(mockPrefs.getString('onboarding_data')).called(1);
      });

      test('should handle corrupted onboarding data gracefully', () async {
        // Arrange
        when(mockPrefs.getString('onboarding_data')).thenReturn('invalid json');

        // Act & Assert
        expect(() => service.getOnboardingData(), throwsA(isA<Exception>()));
      });

      test('should clear onboarding data', () async {
        // Arrange
        when(mockPrefs.remove('onboarding_data')).thenAnswer((_) async => true);

        // Act
        await service.clearOnboardingData();

        // Assert
        verify(mockPrefs.remove('onboarding_data')).called(1);
      });

      test('should handle save failures', () async {
        // Arrange
        final testData = {'userName': 'John Doe'};
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => service.saveOnboardingData(testData),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('PIN storage (secure)', () {
      test('should save PIN securely', () async {
        // Arrange
        const testPin = '1234';
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        // Act
        await service.savePinSecurely(testPin);

        // Assert
        verify(mockSecureStorage.write(key: 'user_pin', value: testPin)).called(1);
      });

      test('should retrieve PIN securely', () async {
        // Arrange
        const testPin = '1234';
        when(mockSecureStorage.read(key: 'user_pin')).thenAnswer((_) async => testPin);

        // Act
        final result = await service.getPinSecurely();

        // Assert
        expect(result, equals(testPin));
        verify(mockSecureStorage.read(key: 'user_pin')).called(1);
      });

      test('should return null when no PIN exists', () async {
        // Arrange
        when(mockSecureStorage.read(key: 'user_pin')).thenAnswer((_) async => null);

        // Act
        final result = await service.getPinSecurely();

        // Assert
        expect(result, isNull);
        verify(mockSecureStorage.read(key: 'user_pin')).called(1);
      });

      test('should delete PIN securely', () async {
        // Arrange
        when(mockSecureStorage.delete(key: 'user_pin')).thenAnswer((_) async => {});

        // Act
        await service.deletePinSecurely();

        // Assert
        verify(mockSecureStorage.delete(key: 'user_pin')).called(1);
      });

      test('should handle secure storage errors', () async {
        // Arrange
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenThrow(Exception('Secure storage error'));

        // Act & Assert
        expect(
          () => service.savePinSecurely('1234'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('onboarding completion status', () {
      test('should check if onboarding is complete', () async {
        // Arrange
        const jsonData = '''
        {
          "userName": "John Doe",
          "isComplete": true
        }
        ''';
        when(mockPrefs.getString('onboarding_data')).thenReturn(jsonData);

        // Act
        final result = await service.isOnboardingComplete();

        // Assert
        expect(result, isTrue);
      });

      test('should return false when onboarding is not complete', () async {
        // Arrange
        const jsonData = '''
        {
          "userName": "John Doe",
          "isComplete": false
        }
        ''';
        when(mockPrefs.getString('onboarding_data')).thenReturn(jsonData);

        // Act
        final result = await service.isOnboardingComplete();

        // Assert
        expect(result, isFalse);
      });

      test('should return false when no onboarding data exists', () async {
        // Arrange
        when(mockPrefs.getString('onboarding_data')).thenReturn(null);

        // Act
        final result = await service.isOnboardingComplete();

        // Assert
        expect(result, isFalse);
      });

      test('should mark onboarding as complete', () async {
        // Arrange
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act
        await service.markOnboardingComplete();

        // Assert
        verify(mockPrefs.setString('onboarding_data', any)).called(1);
      });
    });

    group('user preferences', () {
      test('should save user preference', () async {
        // Arrange
        when(mockPrefs.setBool('test_key', true)).thenAnswer((_) async => true);

        // Act
        await service.saveUserPreference('test_key', true);

        // Assert
        verify(mockPrefs.setBool('test_key', true)).called(1);
      });

      test('should save string preference', () async {
        // Arrange
        when(mockPrefs.setString('test_key', 'test_value')).thenAnswer((_) async => true);

        // Act
        await service.saveUserPreference('test_key', 'test_value');

        // Assert
        verify(mockPrefs.setString('test_key', 'test_value')).called(1);
      });

      test('should save int preference', () async {
        // Arrange
        when(mockPrefs.setInt('test_key', 42)).thenAnswer((_) async => true);

        // Act
        await service.saveUserPreference('test_key', 42);

        // Assert
        verify(mockPrefs.setInt('test_key', 42)).called(1);
      });

      test('should save double preference', () async {
        // Arrange
        when(mockPrefs.setDouble('test_key', 3.14)).thenAnswer((_) async => true);

        // Act
        await service.saveUserPreference('test_key', 3.14);

        // Assert
        verify(mockPrefs.setDouble('test_key', 3.14)).called(1);
      });

      test('should get user preference', () async {
        // Arrange
        when(mockPrefs.get('test_key')).thenReturn('test_value');

        // Act
        final result = service.getUserPreference('test_key');

        // Assert
        expect(result, equals('test_value'));
        verify(mockPrefs.get('test_key')).called(1);
      });

      test('should return default value when preference does not exist', () async {
        // Arrange
        when(mockPrefs.get('test_key')).thenReturn(null);

        // Act
        final result = service.getUserPreference('test_key', defaultValue: 'default');

        // Assert
        expect(result, equals('default'));
      });

      test('should handle unsupported preference types', () async {
        // Act & Assert
        expect(
          () => service.saveUserPreference('test_key', [1, 2, 3]),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('data validation', () {
      test('should validate onboarding data structure', () async {
        // Arrange
        final validData = {
          'userName': 'John Doe',
          'virtualNumber': '+1234567890',
          'termsAccepted': true,
          'currentStep': 2,
          'isComplete': false,
        };

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act & Assert - should not throw
        await service.saveOnboardingData(validData);
      });

      test('should handle empty onboarding data', () async {
        // Arrange
        final emptyData = <String, dynamic>{};
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act & Assert - should not throw
        await service.saveOnboardingData(emptyData);
      });

      test('should handle null values in onboarding data', () async {
        // Arrange
        final dataWithNulls = {
          'userName': null,
          'virtualNumber': '+1234567890',
          'termsAccepted': true,
        };

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        // Act & Assert - should not throw
        await service.saveOnboardingData(dataWithNulls);
      });
    });

    group('error handling', () {
      test('should handle SharedPreferences exceptions', () async {
        // Arrange
        when(mockPrefs.getString(any)).thenThrow(Exception('SharedPreferences error'));

        // Act & Assert
        expect(
          () => service.getOnboardingData(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle FlutterSecureStorage exceptions', () async {
        // Arrange
        when(mockSecureStorage.read(key: anyNamed('key')))
            .thenThrow(Exception('Secure storage error'));

        // Act & Assert
        expect(
          () => service.getPinSecurely(),
          throwsA(isA<Exception>()),
        );
      });

      test('should provide meaningful error messages', () async {
        // Arrange
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => false);

        // Act & Assert
        try {
          await service.saveOnboardingData({'test': 'data'});
          fail('Expected exception');
        } catch (e) {
          expect(e.toString(), contains('Failed to save onboarding data'));
        }
      });
    });

    group('data migration', () {
      test('should handle legacy data format', () async {
        // Arrange - simulate old data format
        const legacyJsonData = '''
        {
          "name": "John Doe",
          "phone": "+1234567890",
          "terms": true
        }
        ''';

        when(mockPrefs.getString('onboarding_data')).thenReturn(legacyJsonData);

        // Act
        final result = await service.getOnboardingData();

        // Assert - should still parse successfully
        expect(result, isNotNull);
        expect(result!['name'], equals('John Doe'));
        expect(result['phone'], equals('+1234567890'));
        expect(result['terms'], equals(true));
      });
    });
  });
}