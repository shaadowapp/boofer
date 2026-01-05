import 'package:flutter_test/flutter_test.dart';
import 'package:boofer/utils/virtual_number_generator.dart';

void main() {
  group('VirtualNumberGenerator', () {
    late VirtualNumberGenerator generator;

    setUp(() {
      generator = VirtualNumberGenerator();
    });

    group('number generation', () {
      test('should generate a valid phone number format', () {
        // Act
        final number = generator.generateUniqueNumber();

        // Assert
        expect(number, isNotNull);
        expect(number, isNotEmpty);
        expect(number, startsWith('+1'));
        expect(number.length, equals(12)); // +1 + 10 digits
        expect(RegExp(r'^\+1\d{10}$').hasMatch(number), isTrue);
      });

      test('should generate unique numbers on multiple calls', () {
        // Act
        final numbers = <String>{};
        for (int i = 0; i < 100; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        expect(numbers.length, equals(100)); // All should be unique
      });

      test('should generate numbers with valid area codes', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 50; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          final areaCode = number.substring(2, 5); // Extract area code
          final areaCodeInt = int.parse(areaCode);
          
          // Area code should be between 200-999 (excluding some reserved ranges)
          expect(areaCodeInt, greaterThanOrEqualTo(200));
          expect(areaCodeInt, lessThanOrEqualTo(999));
          
          // First digit of area code should not be 0 or 1
          expect(areaCode[0], isNot(equals('0')));
          expect(areaCode[0], isNot(equals('1')));
        }
      });

      test('should generate numbers with valid exchange codes', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 50; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          final exchangeCode = number.substring(5, 8); // Extract exchange code
          final exchangeCodeInt = int.parse(exchangeCode);
          
          // Exchange code should be between 200-999
          expect(exchangeCodeInt, greaterThanOrEqualTo(200));
          expect(exchangeCodeInt, lessThanOrEqualTo(999));
          
          // First digit of exchange code should not be 0 or 1
          expect(exchangeCode[0], isNot(equals('0')));
          expect(exchangeCode[0], isNot(equals('1')));
        }
      });

      test('should generate numbers with valid subscriber numbers', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 50; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          final subscriberNumber = number.substring(8); // Extract last 4 digits
          expect(subscriberNumber.length, equals(4));
          expect(RegExp(r'^\d{4}$').hasMatch(subscriberNumber), isTrue);
          
          // Should not be all zeros
          expect(subscriberNumber, isNot(equals('0000')));
        }
      });
    });

    group('number validation', () {
      test('should avoid reserved number patterns', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 1000; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert - check for common reserved patterns
        for (final number in numbers) {
          // Should not start with +1555 (often used for fictional numbers)
          expect(number, isNot(startsWith('+1555')));
          
          // Should not be emergency numbers
          expect(number, isNot(equals('+19110000000')));
          expect(number, isNot(equals('+14110000000')));
          
          // Should not be test numbers
          expect(number, isNot(startsWith('+1800555')));
          expect(number, isNot(startsWith('+1888555')));
        }
      });

      test('should generate numbers that look realistic', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 100; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          // Should not have obvious patterns like all same digits
          final digits = number.substring(2); // Remove +1
          expect(digits, isNot(equals('0000000000')));
          expect(digits, isNot(equals('1111111111')));
          expect(digits, isNot(equals('2222222222')));
          expect(digits, isNot(equals('9999999999')));
          
          // Should not be sequential
          expect(digits, isNot(equals('1234567890')));
          expect(digits, isNot(equals('0123456789')));
        }
      });
    });

    group('performance', () {
      test('should generate numbers quickly', () {
        // Act & Assert
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          generator.generateUniqueNumber();
        }
        
        stopwatch.stop();
        
        // Should generate 1000 numbers in less than 1 second
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('should maintain uniqueness under rapid generation', () {
        // Act
        final numbers = <String>{};
        final futures = <Future<void>>[];
        
        for (int i = 0; i < 100; i++) {
          futures.add(Future(() {
            numbers.add(generator.generateUniqueNumber());
          }));
        }
        
        // Wait for all generations to complete
        return Future.wait(futures).then((_) {
          // Assert
          expect(numbers.length, equals(100)); // All should be unique
        });
      });
    });

    group('edge cases', () {
      test('should handle multiple generator instances', () {
        // Arrange
        final generator1 = VirtualNumberGenerator();
        final generator2 = VirtualNumberGenerator();

        // Act
        final numbers1 = <String>{};
        final numbers2 = <String>{};
        
        for (int i = 0; i < 50; i++) {
          numbers1.add(generator1.generateUniqueNumber());
          numbers2.add(generator2.generateUniqueNumber());
        }

        // Assert
        expect(numbers1.length, equals(50));
        expect(numbers2.length, equals(50));
        
        // There might be some overlap between instances, but each should be internally unique
        final allNumbers = {...numbers1, ...numbers2};
        expect(allNumbers.length, greaterThanOrEqualTo(90)); // Allow some overlap
      });

      test('should generate consistent format across all numbers', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 100; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          expect(number.length, equals(12));
          expect(number, startsWith('+1'));
          expect(number.substring(2), matches(RegExp(r'^\d{10}$')));
        }
      });
    });

    group('number format validation', () {
      test('should follow North American Numbering Plan (NANP)', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 100; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          // Format: +1NXXNXXXXXX where N = 2-9, X = 0-9
          final areaCode = number.substring(2, 5);
          final exchangeCode = number.substring(5, 8);
          
          // Area code first digit should be 2-9
          final areaFirstDigit = int.parse(areaCode[0]);
          expect(areaFirstDigit, greaterThanOrEqualTo(2));
          expect(areaFirstDigit, lessThanOrEqualTo(9));
          
          // Exchange code first digit should be 2-9
          final exchangeFirstDigit = int.parse(exchangeCode[0]);
          expect(exchangeFirstDigit, greaterThanOrEqualTo(2));
          expect(exchangeFirstDigit, lessThanOrEqualTo(9));
        }
      });

      test('should not generate toll-free or premium numbers', () {
        // Act
        final numbers = <String>[];
        for (int i = 0; i < 200; i++) {
          numbers.add(generator.generateUniqueNumber());
        }

        // Assert
        for (final number in numbers) {
          final areaCode = number.substring(2, 5);
          
          // Should not be toll-free numbers
          expect(areaCode, isNot(equals('800')));
          expect(areaCode, isNot(equals('833')));
          expect(areaCode, isNot(equals('844')));
          expect(areaCode, isNot(equals('855')));
          expect(areaCode, isNot(equals('866')));
          expect(areaCode, isNot(equals('877')));
          expect(areaCode, isNot(equals('888')));
          
          // Should not be premium numbers
          expect(areaCode, isNot(equals('900')));
          expect(areaCode, isNot(equals('976')));
        }
      });
    });
  });
}