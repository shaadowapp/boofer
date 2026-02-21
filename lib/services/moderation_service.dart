/// Content moderation service for Boofer.
/// Used for both field validation (handles, bios) and chat message moderation.
class ModerationService {
  // ---------------------------------------------------------------------------
  // Field validation (handles, names, bios)
  // ---------------------------------------------------------------------------

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
  ];

  static String? validateField(String fieldName, String value) {
    if (value.isEmpty) return '$fieldName cannot be empty';

    final lowercaseValue = value.toLowerCase();

    for (final word in reservedWords) {
      if (lowercaseValue.contains(word)) {
        return 'The word "$word" is reserved and cannot be used in $fieldName';
      }
    }

    for (final pattern in prohibitedPatterns) {
      if (lowercaseValue.contains(pattern)) {
        return '$fieldName contains prohibited commercial content';
      }
    }

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

  // ---------------------------------------------------------------------------
  // Chat message moderation
  // ---------------------------------------------------------------------------

  /// Checks [text] for illegal or harmful content.
  /// Returns a [ModerationResult] with [isAllowed] = false and a [reason]
  /// string if the message should be blocked.
  static ModerationResult moderateMessage(String text) {
    final lower = text.toLowerCase();

    // ---- Drugs & narcotics ----
    const drugTerms = [
      'buy weed',
      'sell weed',
      'buy drugs',
      'sell drugs',
      'drug deal',
      'drug dealer',
      'heroin',
      'meth',
      'methamphetamine',
      'fentanyl',
      'cocaine',
      'crack cocaine',
      'opioid',
      'mdma supply',
      'lsd supply',
      'darknet',
      'dark web drugs',
      'drug traffick',
    ];
    for (final term in drugTerms) {
      if (lower.contains(term)) {
        return ModerationResult.blocked(
          'Your message may contain content related to illegal drug activity.',
        );
      }
    }

    // ---- Human trafficking / exploitation ----
    const traffickingTerms = [
      'human traffick',
      'sex traffick',
      'escort service',
      'buy girl',
      'sell girl',
      'child porn',
      'cp link',
      'underage sex',
      'minor nude',
      'sell minor',
      'prostitut',
    ];
    for (final term in traffickingTerms) {
      if (lower.contains(term)) {
        return ModerationResult.blocked(
          'Your message may contain content related to human trafficking or exploitation.',
        );
      }
    }

    // ---- Weapons & violence for hire ----
    const weaponTerms = [
      'buy gun illegally',
      'sell gun',
      'illegal weapon',
      'bomb threat',
      'bomb making',
      'explosive device',
      'pipe bomb',
      'molotov',
      'hitman',
      'murder for hire',
      'kill for money',
      'assassination',
    ];
    for (final term in weaponTerms) {
      if (lower.contains(term)) {
        return ModerationResult.blocked(
          'Your message may contain content related to illegal weapons or violence for hire.',
        );
      }
    }

    // ---- Terrorism & extremism ----
    const terrorismTerms = [
      'terrorist attack',
      'mass shooting plan',
      'jihad attack',
      'bomb public',
      'recruit terrorists',
      'extremist cell',
    ];
    for (final term in terrorismTerms) {
      if (lower.contains(term)) {
        return ModerationResult.blocked(
          'Your message may contain content related to terrorism or extremist activity.',
        );
      }
    }

    // ---- Financial fraud & scams ----
    const fraudTerms = [
      'money laundering',
      'pyramid scheme',
      'ponzi scheme',
      'phishing link',
      'fake kyc',
      'blackmail',
      'ransomware',
      'credit card fraud',
      'wire fraud',
      'identity theft scheme',
    ];
    for (final term in fraudTerms) {
      if (lower.contains(term)) {
        return ModerationResult.blocked(
          'Your message may contain content related to financial fraud or scams.',
        );
      }
    }

    // ---- Commercial solicitation (existing prohibitedPatterns context) ----
    const commercialTerms = [
      'paid vc',
      'paid service',
      'hire me for',
      'pay me for',
    ];
    for (final term in commercialTerms) {
      if (lower.contains(term)) {
        return ModerationResult.blocked(
          'Your message may contain prohibited commercial solicitation.',
        );
      }
    }

    return ModerationResult.allowed();
  }
}

/// Result returned by [ModerationService.moderateMessage].
class ModerationResult {
  final bool isAllowed;
  final String? reason;

  const ModerationResult._({required this.isAllowed, this.reason});

  factory ModerationResult.allowed() =>
      const ModerationResult._(isAllowed: true);

  factory ModerationResult.blocked(String reason) =>
      ModerationResult._(isAllowed: false, reason: reason);
}
