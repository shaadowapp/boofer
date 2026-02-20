import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VirgilE2EEService {
  static VirgilE2EEService? _instance;
  static VirgilE2EEService get instance =>
      _instance ??= VirgilE2EEService._internal();
  VirgilE2EEService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _initialized = false;
  String? _userId;
  String? get userId => _userId;

  // Cryptographic algorithms
  final x25519 = X25519(); // For Key Agreement (ECIES)
  final ed25519 = Ed25519(); // For Digital Signatures
  final aesGcm = AesGcm.with256bits(); // For Symmetric Encryption

  // Keys
  KeyPair? _encryptionKeyPair; // X25519
  KeyPair? _signatureKeyPair; // Ed25519

  bool get isInitialized => _initialized;

  Future<void> initialize(String userId) async {
    if (_initialized && _userId == userId) return;
    _userId = userId;

    debugPrint('🔐 Initializing Virgil-style E2EE for user: $userId');

    try {
      // 1. Load or generate X25519 key pair (for ECIES)
      final encryptionPrivateKeyBase64 = await _storage.read(
        key: 'v_enc_private_$userId',
      );
      if (encryptionPrivateKeyBase64 != null) {
        final privateKeyBytes = base64Decode(encryptionPrivateKeyBase64);
        _encryptionKeyPair = await x25519.newKeyPairFromSeed(privateKeyBytes);
      } else {
        debugPrint('🔑 Generating fresh X25519 encryption keys...');
        _encryptionKeyPair = await x25519.newKeyPair();
        final keyPairData = await _encryptionKeyPair!.extract();
        final privateKeyBytes = (keyPairData as SimpleKeyPairData).bytes;
        await _storage.write(
          key: 'v_enc_private_$userId',
          value: base64Encode(privateKeyBytes),
        );
      }

      // 2. Load or generate Ed25519 key pair (for Signatures)
      final signaturePrivateKeyBase64 = await _storage.read(
        key: 'v_sig_private_$userId',
      );
      if (signaturePrivateKeyBase64 != null) {
        final privateKeyBytes = base64Decode(signaturePrivateKeyBase64);
        _signatureKeyPair = await ed25519.newKeyPairFromSeed(privateKeyBytes);
      } else {
        debugPrint('🔑 Generating fresh Ed25519 signature keys...');
        _signatureKeyPair = await ed25519.newKeyPair();
        final keyPairData = await _signatureKeyPair!.extract();
        final privateKeyBytes = (keyPairData as SimpleKeyPairData).bytes;
        await _storage.write(
          key: 'v_sig_private_$userId',
          value: base64Encode(privateKeyBytes),
        );
      }

      _initialized = true;
      debugPrint('✅ Virgil-style E2EE Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Virgil-style E2EE: $e');
      rethrow;
    }
  }

  Future<Uint8List> getEncryptionPublicKey() async {
    final pk = await _encryptionKeyPair!.extractPublicKey();
    return Uint8List.fromList((pk as SimplePublicKey).bytes);
  }

  Future<Uint8List> getSignaturePublicKey() async {
    final pk = await _signatureKeyPair!.extractPublicKey();
    return Uint8List.fromList((pk as SimplePublicKey).bytes);
  }

  /// Virgil-style: Encrypt message for recipient and SIGN with sender's key
  Future<Map<String, dynamic>> encryptThenSign(
    String plaintext,
    Uint8List recipientEncryptionPublicKey,
  ) async {
    if (!_initialized) throw Exception('E2EE not initialized');

    // 1. Generate Ephemeral Key Pair for ECIES
    final ephemeralKeyPair = await x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    // 2. Perform Key Agreement (Diffie-Hellman)
    final recipientPublicKey = SimplePublicKey(
      recipientEncryptionPublicKey.toList(),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: recipientPublicKey,
    );

    // 3. Derive Symmetric Key using HKDF (Simple version for now, matching common Virgil pattern)
    // Virgil often uses the shared secret directly with some KDF
    final sharedSecretBytes = await sharedSecret.extractBytes();
    final symmetricKey = await aesGcm.newSecretKeyFromBytes(
      sharedSecretBytes.sublist(0, 32),
    );

    // 4. Encrypt with AES-GCM
    final nonce = aesGcm.newNonce();
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await aesGcm.encrypt(
      plaintextBytes,
      secretKey: symmetricKey,
      nonce: nonce,
    );

    // 5. Sign the Ciphertext (Original Virgil pattern: sign(ciphertext + metadata))
    final signature = await ed25519.sign(
      secretBox.cipherText,
      keyPair: _signatureKeyPair!,
    );

    // 6. Return Cryptogram
    return {
      'ephemeralKey': base64Encode(ephemeralPublicKey.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'signature': base64Encode(signature.bytes),
      'v': '1.0',
    };
  }

  /// Virgil-style: Decrypt message and VERIFY sender's signature
  Future<String> decryptThenVerify(
    Map<String, dynamic> cryptogram,
    Uint8List senderSignaturePublicKey,
  ) async {
    if (!_initialized) throw Exception('E2EE not initialized');

    try {
      final ephemeralKeyBytes = base64Decode(cryptogram['ephemeralKey']);
      final ciphertext = base64Decode(cryptogram['ciphertext']);
      final nonce = base64Decode(cryptogram['nonce']);
      final mac = base64Decode(cryptogram['mac']);
      final signatureBytes = base64Decode(cryptogram['signature']);

      // 1. Verify Signature FIRST (Virgil's decryptThenVerify typically verifies integrity)
      final senderPublicKey = SimplePublicKey(
        senderSignaturePublicKey,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(signatureBytes, publicKey: senderPublicKey);

      final isVerified = await ed25519.verify(ciphertext, signature: signature);

      if (!isVerified) {
        throw Exception(
          'Signature verification failed! Message may have been tampered with.',
        );
      }

      // 2. Perform Key Agreement (Diffie-Hellman)
      final ephemeralPubKey = SimplePublicKey(
        ephemeralKeyBytes,
        type: KeyPairType.x25519,
      );
      final sharedSecret = await x25519.sharedSecretKey(
        keyPair: _encryptionKeyPair!,
        remotePublicKey: ephemeralPubKey,
      );

      // 3. Derive Symmetric Key
      final sharedSecretBytes = await sharedSecret.extractBytes();
      final symmetricKey = await aesGcm.newSecretKeyFromBytes(
        sharedSecretBytes.sublist(0, 32),
      );

      // 4. Decrypt with AES-GCM
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));

      final decryptedBytes = await aesGcm.decrypt(
        secretBox,
        secretKey: symmetricKey,
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('❌ Decryption/Verification error: $e');
      rethrow;
    }
  }
}
