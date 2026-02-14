class StringUtils {
  /// Formats a virtual number string into XXX-XXX-XXXX format.
  /// Handles both numeric strings and strings with existing dashes/prefixes.
  static String formatVirtualNumber(String? number) {
    if (number == null || number.isEmpty) return 'No number';
    if (number.length < 5) return number; // Don't format very short strings

    // Remove "BN-", "VN-", and any other non-digit characters
    final digits = number.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }

    // If it's not 10 digits, just return the original or cleaned digits
    return number;
  }

  /// Checks if a string is a valid UUID
  static bool isUuid(String? s) {
    if (s == null) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(s);
  }
}
