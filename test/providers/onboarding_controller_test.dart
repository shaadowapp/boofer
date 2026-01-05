import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:boofer/providers/onboarding_controller.dart';
import 'package:boofer/services/local_storage_service.dart';
import 'package:boofer/utils/virtual_number_generator.dart';

import 'onboarding_controller_test.mocks.dart';

@GenerateMocks([LocalStorageService, VirtualNumberGenerator])
void main() {
  group('OnboardingController', () {
    late OnboardingController controller;
    late MockLocalStorageService mockStorageService;
    late MockVirtualNumberGenerator mockNumberGenerator;

    setUp(() {
      mockStorageService = MockLocalStorageService();
      mockNumberGenerator = MockVirtualNumberGenerator();
      controller = OnboardingController(
        storageService: mockStorageService,
        numberGenerator: mockNumberGenerator,
      );
    });

    group('initialization', () {
      test('should initialize with default values', () {
        expect(controller.currentStep, equals(1));
        expect(controller.userName, isEmpty);
        expect(controller.virtualNumber, isEmpty);
        expect(controller.userPin, isNull);
        expect(controller.termsAccepted, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.errorMessage, isNull);
        expect(controller.isOnboardingComplete, isFalse);
      });

      test('should load existing data on initialize', () async {
        // Arrange
        when(mockStorageService.getOnboardingData()).thenAnswer(
          (_) async => {
            'userName': 'John Doe',
            'virtualNumber': '+1234567890',
            'termsAccepted': true,
            'currentStep': 2,
            'isComplete': false,
          },
        );

        // Act
        await controller.initialize();

        // Assert
        expect(controller.userName, equals('John Doe'));
        expect(controller.virtualNumber, equals('+1234567890'));
        expect(controller.termsAccepted, isTrue);
        expect(controller.currentStep, equals(2));
        expect(controller.isOnboardingComplete, isFalse);
        verify(mockStorageService.getOnboardingData()).called(1);
      });

      test('should handle initialization errors gracefully', () async {
        // Arrange
        when(mockStorageService.getOnboardingData())
            .thenThrow(Exception('Storage error'));

        // Act
        await controller.initialize();

        // Assert
        expect(controller.errorMessage, contains('Storage error'));
        expect(controller.currentStep, equals(1)); // Should remain at default
      });
    });

    group('user registration', () {
      test('should set user name successfully', () async {
        // Arrange
        const testName = 'John Doe';
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.setUserName(testName);

        // Assert
        expect(controller.userName, equals(testName));
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should validate user name input', () async {
        // Test empty name
        await controller.setUserName('');
        expect(controller.userName, isEmpty);

        // Test whitespace only
        await controller.setUserName('   ');
        expect(controller.userName, equals('   ')); // Should store as-is but validation happens in UI

        // Test valid name
        await controller.setUserName('John Doe');
        expect(controller.userName, equals('John Doe'));
      });

      test('should set terms acceptance', () async {
        // Arrange
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.setTermsAccepted(true);

        // Assert
        expect(controller.termsAccepted, isTrue);
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should handle storage errors during registration', () async {
        // Arrange
        when(mockStorageService.saveOnboardingData(any))
            .thenThrow(Exception('Save failed'));

        // Act
        await controller.setUserName('John Doe');

        // Assert
        expect(controller.errorMessage, contains('Save failed'));
      });
    });

    group('PIN management', () {
      test('should set user PIN successfully', () async {
        // Arrange
        const testPin = '1234';
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.setUserPin(testPin);

        // Assert
        expect(controller.userPin, equals(testPin));
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should clear PIN when set to null', () async {
        // Arrange
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // First set a PIN
        await controller.setUserPin('1234');
        expect(controller.userPin, equals('1234'));

        // Then clear it
        await controller.setUserPin(null);

        // Assert
        expect(controller.userPin, isNull);
      });

      test('should skip PIN setup', () async {
        // Arrange
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.skipPinSetup();

        // Assert
        expect(controller.userPin, isNull);
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should validate PIN format', () async {
        // Test valid 4-digit PIN
        await controller.setUserPin('1234');
        expect(controller.userPin, equals('1234'));

        // Test invalid PIN lengths (should still store but validation happens in UI)
        await controller.setUserPin('123');
        expect(controller.userPin, equals('123'));

        await controller.setUserPin('12345');
        expect(controller.userPin, equals('12345'));
      });
    });

    group('virtual number generation', () {
      test('should generate virtual number successfully', () async {
        // Arrange
        const testNumber = '+1234567890';
        when(mockNumberGenerator.generateUniqueNumber())
            .thenReturn(testNumber);
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.generateVirtualNumber();

        // Assert
        expect(controller.virtualNumber, equals(testNumber));
        verify(mockNumberGenerator.generateUniqueNumber()).called(1);
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should handle number generation errors', () async {
        // Arrange
        when(mockNumberGenerator.generateUniqueNumber())
            .thenThrow(Exception('Generation failed'));

        // Act
        await controller.generateVirtualNumber();

        // Assert
        expect(controller.errorMessage, contains('Generation failed'));
        expect(controller.virtualNumber, isEmpty);
      });

      test('should not regenerate if number already exists', () async {
        // Arrange
        const existingNumber = '+1111111111';
        controller.virtualNumber = existingNumber;

        // Act
        await controller.generateVirtualNumber();

        // Assert
        expect(controller.virtualNumber, equals(existingNumber));
        verifyNever(mockNumberGenerator.generateUniqueNumber());
      });
    });

    group('step navigation', () {
      test('should navigate to next step', () async {
        // Arrange
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.nextStep();

        // Assert
        expect(controller.currentStep, equals(2));
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should not exceed maximum step', () async {
        // Arrange
        controller.currentStep = 3;
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.nextStep();

        // Assert
        expect(controller.currentStep, equals(3)); // Should remain at 3
      });

      test('should navigate to previous step', () {
        // Arrange
        controller.currentStep = 2;

        // Act
        controller.previousStep();

        // Assert
        expect(controller.currentStep, equals(1));
      });

      test('should not go below minimum step', () {
        // Arrange
        controller.currentStep = 1;

        // Act
        controller.previousStep();

        // Assert
        expect(controller.currentStep, equals(1)); // Should remain at 1
      });

      test('should go to specific step', () {
        // Act
        controller.goToStep(3);

        // Assert
        expect(controller.currentStep, equals(3));
      });

      test('should validate step bounds when going to specific step', () {
        // Test below minimum
        controller.goToStep(0);
        expect(controller.currentStep, equals(1));

        // Test above maximum
        controller.goToStep(5);
        expect(controller.currentStep, equals(3));

        // Test valid step
        controller.goToStep(2);
        expect(controller.currentStep, equals(2));
      });
    });

    group('onboarding completion', () {
      test('should complete onboarding successfully', () async {
        // Arrange
        controller.userName = 'John Doe';
        controller.termsAccepted = true;
        controller.virtualNumber = '+1234567890';
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act
        await controller.completeOnboarding();

        // Assert
        expect(controller.isOnboardingComplete, isTrue);
        verify(mockStorageService.saveOnboardingData(any)).called(1);
      });

      test('should validate required data before completion', () async {
        // Test missing user name
        controller.userName = '';
        controller.termsAccepted = true;
        controller.virtualNumber = '+1234567890';

        await controller.completeOnboarding();
        expect(controller.errorMessage, contains('User name is required'));
        expect(controller.isOnboardingComplete, isFalse);

        // Test terms not accepted
        controller.userName = 'John Doe';
        controller.termsAccepted = false;
        controller.virtualNumber = '+1234567890';

        await controller.completeOnboarding();
        expect(controller.errorMessage, contains('Terms must be accepted'));
        expect(controller.isOnboardingComplete, isFalse);

        // Test missing virtual number
        controller.userName = 'John Doe';
        controller.termsAccepted = true;
        controller.virtualNumber = '';

        await controller.completeOnboarding();
        expect(controller.errorMessage, contains('Virtual number is required'));
        expect(controller.isOnboardingComplete, isFalse);
      });

      test('should handle completion errors', () async {
        // Arrange
        controller.userName = 'John Doe';
        controller.termsAccepted = true;
        controller.virtualNumber = '+1234567890';
        when(mockStorageService.saveOnboardingData(any))
            .thenThrow(Exception('Save failed'));

        // Act
        await controller.completeOnboarding();

        // Assert
        expect(controller.errorMessage, contains('Save failed'));
        expect(controller.isOnboardingComplete, isFalse);
      });
    });

    group('error handling', () {
      test('should clear error message', () {
        // Arrange
        controller.errorMessage = 'Test error';

        // Act
        controller.clearError();

        // Assert
        expect(controller.errorMessage, isNull);
      });

      test('should set loading state', () {
        // Act
        controller.setLoading(true);

        // Assert
        expect(controller.isLoading, isTrue);

        // Act
        controller.setLoading(false);

        // Assert
        expect(controller.isLoading, isFalse);
      });
    });

    group('data persistence', () {
      test('should save data after each significant change', () async {
        // Arrange
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((_) async => {});

        // Act - multiple operations
        await controller.setUserName('John Doe');
        await controller.setTermsAccepted(true);
        await controller.setUserPin('1234');
        await controller.nextStep();

        // Assert
        verify(mockStorageService.saveOnboardingData(any)).called(4);
      });

      test('should create correct data structure for saving', () async {
        // Arrange
        controller.userName = 'John Doe';
        controller.termsAccepted = true;
        controller.userPin = '1234';
        controller.virtualNumber = '+1234567890';
        controller.currentStep = 2;

        Map<String, dynamic>? savedData;
        when(mockStorageService.saveOnboardingData(any))
            .thenAnswer((invocation) async {
          savedData = invocation.positionalArguments[0] as Map<String, dynamic>;
        });

        // Act
        await controller.setUserName('John Doe'); // This triggers save

        // Assert
        expect(savedData, isNotNull);
        expect(savedData!['userName'], equals('John Doe'));
        expect(savedData!['termsAccepted'], equals(true));
        expect(savedData!['userPin'], equals('1234'));
        expect(savedData!['virtualNumber'], equals('+1234567890'));
        expect(savedData!['currentStep'], equals(2));
        expect(savedData!['isComplete'], equals(false));
      });
    });
  });
}