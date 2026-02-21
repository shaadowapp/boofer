import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages storage of multiple user profiles on a single device.
/// Each saved account is stored with its Supabase user ID as the key.
class MultiAccountStorageService {
  static const String _savedAccountsKey = 'boofer_saved_accounts_v1';
  static const String _lastActiveAccountKey = 'boofer_last_active_account';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Get list of all saved account summaries (id, handle, fullName, avatar).
  /// These are LIGHT objects suitable for building a picker UI.
  static Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedAccountsKey);
      if (raw == null) return [];
      final List decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Upsert (add or update) an account in the saved-account list.
  static Future<void> upsertAccount({
    required String id,
    required String handle,
    required String fullName,
    String? avatar,
    String? supabaseSession, // raw JSON from supabase session
    bool? isPrimary,
    String? guardianId,
  }) async {
    try {
      final accounts = await getSavedAccounts();

      // Enforce max 3 profiles
      if (accounts.length >= 3 && !accounts.any((a) => a['id'] == id)) {
        throw Exception('Maximum 3 profiles allowed per device');
      }

      final idx = accounts.indexWhere((a) => a['id'] == id);

      // If this is the first account, it's automatically primary
      final effectiveIsPrimary = accounts.isEmpty ? true : (isPrimary ?? false);

      final entry = {
        'id': id,
        'handle': handle,
        'fullName': fullName,
        'avatar': avatar,
        'isPrimary': effectiveIsPrimary,
        'guardianId': guardianId,
        'savedAt': DateTime.now().toIso8601String(),
      };

      if (idx >= 0) {
        accounts[idx] = entry;
      } else {
        accounts.add(entry);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedAccountsKey, jsonEncode(accounts));

      // Store Supabase session securely (if provided)
      if (supabaseSession != null) {
        await _secureStorage.write(
          key: 'boofer_session_$id',
          value: supabaseSession,
        );
      }
    } catch (e) {
      // Silently fail to avoid blocking auth flow
    }
  }

  /// Remove a specific account from saved accounts.
  static Future<void> removeAccount(String id) async {
    try {
      final accounts = await getSavedAccounts();
      accounts.removeWhere((a) => a['id'] == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedAccountsKey, jsonEncode(accounts));
      await _secureStorage.delete(key: 'boofer_session_$id');
    } catch (_) {}
  }

  /// Get the last-active account ID.
  static Future<String?> getLastActiveAccountId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastActiveAccountKey);
    } catch (_) {
      return null;
    }
  }

  /// Set the last-active account ID.
  static Future<void> setLastActiveAccountId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActiveAccountKey, id);
    } catch (_) {}
  }

  /// Get the primary account ID for this device.
  static Future<String?> getPrimaryAccountId() async {
    final accounts = await getSavedAccounts();
    final primary = accounts.firstWhere(
      (a) => a['isPrimary'] == true,
      orElse: () => accounts.isNotEmpty ? accounts.first : {},
    );
    return primary['id'] as String?;
  }

  /// Get the primary account details.
  static Future<Map<String, dynamic>?> getPrimaryAccount() async {
    final accounts = await getSavedAccounts();
    return accounts.firstWhere(
      (a) => a['isPrimary'] == true,
      orElse: () => accounts.isNotEmpty ? accounts.first : {},
    );
  }

  /// Check if a new subordinate profile can be created.
  /// Returns true if count < 3 and currentUserId is the primary account.
  static Future<bool> canCreateSubordinate(String currentUserId) async {
    final accounts = await getSavedAccounts();
    if (accounts.length >= 3) return false;

    final primary = await getPrimaryAccount();
    return primary != null && primary['id'] == currentUserId;
  }

  /// Clear all saved accounts (use on full factory reset).
  static Future<void> clearAll() async {
    try {
      final accounts = await getSavedAccounts();
      for (final a in accounts) {
        await _secureStorage.delete(key: 'boofer_session_${a['id']}');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedAccountsKey);
      await prefs.remove(_lastActiveAccountKey);
    } catch (_) {}
  }

  /// Get secured session for an account.
  static Future<String?> getSession(String id) async {
    try {
      return await _secureStorage.read(key: 'boofer_session_$id');
    } catch (_) {
      return null;
    }
  }
}
