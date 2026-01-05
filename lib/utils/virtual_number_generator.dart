import 'dart:math';

class VirtualNumberGenerator {
  static final Random _random = Random();

  /// Generates a unique 10-digit virtual number
  /// Format: XXX-XXX-XXXX
  static String generate() {
    // Generate 10 random digits
    String number = '';
    for (int i = 0; i < 10; i++) {
      number += _random.nextInt(10).toString();
    }
    
    // Format as XXX-XXX-XXXX
    return '${number.substring(0, 3)}-${number.substring(3, 6)}-${number.substring(6, 10)}';
  }

  /// Generates a unique 10-digit virtual number without formatting
  /// Returns: XXXXXXXXXX
  static String generateUnformatted() {
    String number = '';
    for (int i = 0; i < 10; i++) {
      number += _random.nextInt(10).toString();
    }
    return number;
  }

  /// Validates if a virtual number has the correct format
  static bool isValidFormat(String number) {
    // Check for XXX-XXX-XXXX format
    final RegExp formatRegex = RegExp(r'^\d{3}-\d{3}-\d{4}$');
    return formatRegex.hasMatch(number);
  }

  /// Formats a 10-digit number string to XXX-XXX-XXXX format
  static String formatNumber(String unformattedNumber) {
    if (unformattedNumber.length != 10) {
      throw ArgumentError('Number must be exactly 10 digits');
    }
    
    return '${unformattedNumber.substring(0, 3)}-${unformattedNumber.substring(3, 6)}-${unformattedNumber.substring(6, 10)}';
  }
}