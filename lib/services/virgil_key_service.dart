import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'virgil_e2ee_service.dart';

class VirgilKeyService {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Memory cache for public keys
  static final Map<String, Map<String, dynamic>> _keyCache = {};

  // Pending requests for keys (to flatten concurrent calls)
  static final Map<String, Future<Map<String, dynamic>?>> _pendingRequests = {};

  /// Upload the current user's public keys to Supabase
  // ... (uploadPublicKeys remains same)
  Future<void> uploadPublicKeys() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (!VirgilE2EEService.instance.isInitialized) {
      await VirgilE2EEService.instance.initialize(user.id);
    }

    final encryptionPublicKey = await VirgilE2EEService.instance
        .getEncryptionPublicKey();
    final signaturePublicKey = await VirgilE2EEService.instance
        .getSignaturePublicKey();

    final keyBundle = {
      'encryptionPublicKey': base64Encode(encryptionPublicKey),
      'signaturePublicKey': base64Encode(signaturePublicKey),
      'v': 'virgil_v1',
    };

    debugPrint('📤 Uploading Virgil public keys for ${user.id}...');

    await _supabase.from('user_public_keys').upsert({
      'user_id': user.id,
      'key_bundle': keyBundle,
      'updated_at': DateTime.now().toIso8601String(),
    });

    debugPrint('✅ Virgil public keys uploaded successfully');
  }

  /// Fetch public keys for a specific recipient
  Future<Map<String, dynamic>?> getRecipientKeys(String recipientId) async {
    // 1. Check cache first
    if (_keyCache.containsKey(recipientId)) {
      return _keyCache[recipientId];
    }

    // 2. Check for pending request to flatten calls
    if (_pendingRequests.containsKey(recipientId)) {
      return _pendingRequests[recipientId];
    }

    // 3. Start new request
    final request = _fetchKeysFromDb(recipientId);
    _pendingRequests[recipientId] = request;

    try {
      final keys = await request;
      if (keys != null) {
        _keyCache[recipientId] = keys;
      }
      return keys;
    } finally {
      _pendingRequests.remove(recipientId);
    }
  }

  Future<Map<String, dynamic>?> _fetchKeysFromDb(String recipientId) async {
    try {
      final response = await _supabase
          .from('user_public_keys')
          .select('key_bundle')
          .eq('user_id', recipientId)
          .maybeSingle();

      if (response == null) return null;

      final bundle = response['key_bundle'] as Map<String, dynamic>;

      // Check if it's a Virgil bundle
      if (bundle['v'] != 'virgil_v1') {
        debugPrint('⚠️ Warning: Found non-Virgil key bundle for $recipientId');
        return null;
      }

      return {
        'encryptionPublicKey': base64Decode(bundle['encryptionPublicKey']),
        'signaturePublicKey': base64Decode(bundle['signaturePublicKey']),
      };
    } catch (e) {
      debugPrint('❌ Error fetching keys for $recipientId: $e');
      return null;
    }
  }
}
