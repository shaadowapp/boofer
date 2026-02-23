import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'persistent_signal_protocol_store.dart';

class E2EEService {
  static E2EEService? _instance;
  static E2EEService get instance => _instance ??= E2EEService._internal();
  E2EEService._internal();

  PersistentSignalProtocolStore? _protocolStore;
  bool _initialized = false;
  String? _currentUserId;

  bool get isInitialized => _initialized;

  Future<void> initialize(String userId) async {
    if (_initialized && _currentUserId == userId) return;

    debugPrint('🔐 Initializing E2EE for user: $userId');
    _currentUserId = userId;
    _protocolStore = PersistentSignalProtocolStore(userId);

    try {
      // Check if we already have identity keys
      await _protocolStore!.getIdentityKeyPair();
    } catch (e) {
      debugPrint('🔑 Generating fresh identity keys for E2EE...');
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);

      await _protocolStore!.saveIdentityKeyPair(identityKeyPair);
      await _protocolStore!.saveLocalRegistrationId(registrationId);

      // Also generate initial pre-keys
      await generateAndStorePreKeys(0, 100);

      // Generate a signed pre-key
      final signedPreKey = generateSignedPreKey(identityKeyPair, 0);
      await _protocolStore!.storeSignedPreKey(0, signedPreKey);
    }

    _initialized = true;
    debugPrint('✅ E2EE Service initialized');
  }

  Future<void> generateAndStorePreKeys(int start, int count) async {
    if (_protocolStore == null) return;

    final preKeys = generatePreKeys(start, count);
    for (final preKey in preKeys) {
      await _protocolStore!.storePreKey(preKey.id, preKey);
    }
    debugPrint('✅ Generated and stored $count pre-keys');
  }

  Future<CiphertextMessage> encryptMessage(
    String plaintext,
    String recipientId,
  ) async {
    if (!_initialized || _protocolStore == null) {
      throw Exception('E2EEService not initialized');
    }

    final address = SignalProtocolAddress(recipientId, 1);
    final sessionCipher = SessionCipher.fromStore(_protocolStore!, address);

    final plaintextBytes = Uint8List.fromList(plaintext.codeUnits);
    final ciphertext = await sessionCipher.encrypt(plaintextBytes);

    return ciphertext;
  }

  Future<String> decryptMessage(
    CiphertextMessage ciphertext,
    String senderId,
  ) async {
    if (!_initialized || _protocolStore == null) {
      throw Exception('E2EEService not initialized');
    }

    final address = SignalProtocolAddress(senderId, 1);
    final sessionCipher = SessionCipher.fromStore(_protocolStore!, address);

    Uint8List plaintextBytes;
    if (ciphertext is PreKeySignalMessage) {
      plaintextBytes = await sessionCipher.decrypt(ciphertext);
    } else if (ciphertext is SignalMessage) {
      plaintextBytes = await sessionCipher.decryptFromSignal(ciphertext);
    } else {
      throw Exception('Unknown ciphertext type');
    }

    return String.fromCharCodes(plaintextBytes);
  }

  Future<IdentityKeyPair> getIdentityKeyPair() async {
    if (_protocolStore == null) throw Exception('Not initialized');
    return await _protocolStore!.getIdentityKeyPair();
  }

  Future<int> getLocalRegistrationId() async {
    if (_protocolStore == null) throw Exception('Not initialized');
    return await _protocolStore!.getLocalRegistrationId();
  }

  Future<SignedPreKeyRecord> getSignedPreKey(int id) async {
    if (_protocolStore == null) throw Exception('Not initialized');
    return await _protocolStore!.loadSignedPreKey(id);
  }

  Future<PreKeyRecord> getPreKey(int id) async {
    if (_protocolStore == null) throw Exception('Not initialized');
    return await _protocolStore!.loadPreKey(id);
  }
}
