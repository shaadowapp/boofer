import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'virgil_e2ee_service.dart';

class VirgilKeyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Memory cache for public keys
  static final Map<String, Map<String, dynamic>> _keyCache = {};

  /// Upload the current user's public keys to Supabase
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
    try {
      // Check cache first
      if (_keyCache.containsKey(recipientId)) {
        return _keyCache[recipientId];
      }

      final response = await _supabase
          .from('user_public_keys')
          .select('key_bundle')
          .eq('user_id', recipientId)
          .single();

      final bundle = response['key_bundle'] as Map<String, dynamic>;

      // Check if it's a Virgil bundle
      if (bundle['v'] != 'virgil_v1') {
        debugPrint('⚠️ Warning: Found non-Virgil key bundle for $recipientId');
        return null;
      }

      final keys = {
        'encryptionPublicKey': base64Decode(bundle['encryptionPublicKey']),
        'signaturePublicKey': base64Decode(bundle['signaturePublicKey']),
      };

      // Store in cache
      _keyCache[recipientId] = keys;
      return keys;
    } catch (e) {
      debugPrint('❌ Error fetching keys for $recipientId: $e');
      return null;
    }
  }
}
