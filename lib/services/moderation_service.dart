class ModerationService {
  static const List<String> reservedWords = [
    'boofer',
    'admin',
    'official',
    'support',
    'moderator',
    'system',
    'verify',
    'verified',
    'staff',
    'help',
  ];

  static const List<String> prohibitedPatterns = [
    'paid vc',
    'paid service',
    'escort',
    'commercial',
    'money',
    'selling',
    'service',
    'price',
    'dollar',
    'rupee',
    'payment',
    'cash',
    'hire',
    'booking',
    'rates',
    'deal',
    'crypto',
    'investment',
  ];

  static const List<String> badWords = [
    'fuck',
    'shit',
    'asshole',
    'bitch',
    'dick',
    'pussy',
    // Add more as needed, but for now these are placeholders
  ];

  static String? validateField(String fieldName, String value) {
    if (value.isEmpty) return '$fieldName cannot be empty';

    final lowercaseValue = value.toLowerCase();

    // Reserved words check
    for (final word in reservedWords) {
      if (lowercaseValue.contains(word)) {
        return 'The word "$word" is reserved and cannot be used in $fieldName';
      }
    }

    // Prohibited patterns check
    for (final pattern in prohibitedPatterns) {
      if (lowercaseValue.contains(pattern)) {
        return '$fieldName contains prohibited commercial content';
      }
    }

    // Bad words check
    for (final word in badWords) {
      if (lowercaseValue.contains(word)) {
        return '$fieldName contains inappropriate language';
      }
    }

    if (fieldName == 'Handle') {
      if (value.length < 3) return 'Handle must be at least 3 characters';
      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
        return 'Handle can only contain letters, numbers, underscores, and dots';
      }
    }

    if (fieldName == 'Name') {
      if (value.length < 2) return 'Name must be at least 2 characters';
      if (RegExp(r'[0-9]').hasMatch(value)) {
        return 'Name cannot contain numbers';
      }
    }

    if (fieldName == 'Bio') {
      if (value.length > 200) return 'Bio must be less than 200 characters';
    }

    return null;
  }
}
