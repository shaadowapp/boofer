import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'e2ee_service.dart';
import 'persistent_signal_protocol_store.dart';

class E2EEKeyService {
  static E2EEKeyService? _instance;
  static E2EEKeyService get instance =>
      _instance ??= E2EEKeyService._internal();
  E2EEKeyService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final E2EEService _e2eeService = E2EEService.instance;

  /// Upload the public key bundle for the current user to Supabase
  Future<void> uploadPublicKeyBundle(String userId) async {
    try {
      if (!_e2eeService.isInitialized) {
        await _e2eeService.initialize(userId);
      }

      final identityKeyPair = await _e2eeService.getIdentityKeyPair();
      final registrationId = await _e2eeService.getLocalRegistrationId();
      final signedPreKey = await _e2eeService.getSignedPreKey(0);

      // Collect one-time pre-keys (e.g., first 100)
      final preKeysJson = [];
      for (int i = 0; i < 100; i++) {
        try {
          final preKey = await _e2eeService.getPreKey(i);
          preKeysJson.add({
            'keyId': preKey.id,
            'publicKey': base64Encode(
              preKey.getKeyPair().publicKey.serialize(),
            ),
          });
        } catch (e) {
          // PreKey might not exist, stop collecting
          break;
        }
      }

      final bundleData = {
        'registrationId': registrationId,
        'identityKey': base64Encode(identityKeyPair.getPublicKey().serialize()),
        'signedPreKey': {
          'keyId': signedPreKey.id,
          'publicKey': base64Encode(
            signedPreKey.getKeyPair().publicKey.serialize(),
          ),
          'signature': base64Encode(signedPreKey.signature),
        },
        'preKeys': preKeysJson,
      };

      await _supabase.from('user_public_keys').upsert({
        'user_id': userId,
        'key_bundle': bundleData,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Public key bundle uploaded for $userId');
    } catch (e) {
      debugPrint('❌ Failed to upload public key bundle: $e');
      rethrow;
    }
  }

  /// Fetch a public key bundle for a recipient and establish a session
  Future<void> establishSession(String recipientId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not logged in');

      // Check if session already exists
      final address = SignalProtocolAddress(recipientId, 1);
      final store = PersistentSignalProtocolStore(currentUserId);
      if (await store.containsSession(address)) {
        return;
      }

      // Fetch bundle from Supabase
      final response = await _supabase
          .from('user_public_keys')
          .select('key_bundle')
          .eq('user_id', recipientId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Recipient $recipientId has no E2EE key bundle');
      }

      final bundle = response['key_bundle'];
      final registrationId = bundle['registrationId'] as int;
      final identityKey = IdentityKey.fromBytes(
        base64Decode(bundle['identityKey']),
        0,
      );

      final signedPreKeyData = bundle['signedPreKey'];
      final signedPreKeyId = signedPreKeyData['keyId'] as int;
      final signedPreKeyPublic = Curve.decodePoint(
        base64Decode(signedPreKeyData['publicKey']),
        0,
      );
      final signedPreKeySignature = base64Decode(signedPreKeyData['signature']);

      // Use the first available pre-key
      final preKeys = bundle['preKeys'] as List;
      if (preKeys.isEmpty) {
        throw Exception('No pre-keys in bundle for $recipientId');
      }

      final preKeyData = preKeys.first;
      final preKeyId = preKeyData['keyId'] as int;
      final preKeyPublic = Curve.decodePoint(
        base64Decode(preKeyData['publicKey']),
        0,
      );

      final preKeyBundle = PreKeyBundle(
        registrationId,
        1, // deviceId
        preKeyId,
        preKeyPublic,
        signedPreKeyId,
        signedPreKeyPublic,
        signedPreKeySignature,
        identityKey,
      );

      // SessionBuilder requires 5 arguments: sessionStore, preKeyStore, signedPreKeyStore, identityStore, remoteAddress
      final sessionBuilder = SessionBuilder(
        store,
        store,
        store,
        store,
        address,
      );
      await sessionBuilder.processPreKeyBundle(preKeyBundle);
      debugPrint('✅ E2EE Session established with $recipientId');
    } catch (e, stack) {
      debugPrint('❌ Failed to establish E2EE session with $recipientId: $e');
      debugPrint('❌ Stack trace: $stack');
      rethrow;
    }
  }
}

class PreKeyEntity {
  final int id;
  final ECPublicKey key;
  PreKeyEntity(this.id, this.key);
}

class SignedPreKeyEntity {
  final int id;
  final ECPublicKey key;
  final Uint8List signature;
  SignedPreKeyEntity(this.id, this.key, this.signature);
}
