import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// A persistent implementation of SignalProtocolStore using FlutterSecureStorage
class PersistentSignalProtocolStore extends SignalProtocolStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final String _userId;

  PersistentSignalProtocolStore(this._userId);

  // --- IdentityKeyStore ---

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = 'identity_key_${_userId}_${address.toString()}';
    final value = await _storage.read(key: key);
    if (value == null) return null;
    return IdentityKey.fromBytes(base64Decode(value), 0);
  }

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final key = 'identity_key_pair_$_userId';
    final value = await _storage.read(key: key);
    if (value == null) {
      throw Exception('Identity key pair not found for user $_userId');
    }
    return IdentityKeyPair.fromSerialized(base64Decode(value));
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final key = 'registration_id_$_userId';
    final value = await _storage.read(key: key);
    if (value == null) {
      throw Exception('Registration ID not found for user $_userId');
    }
    return int.parse(value);
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    final trusted = await getIdentity(address);
    return trusted == null || trusted == identityKey;
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    final key = 'identity_key_${_userId}_${address.toString()}';
    if (identityKey == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(
        key: key,
        value: base64Encode(identityKey.serialize()),
      );
    }
    return true;
  }

  Future<void> saveIdentityKeyPair(IdentityKeyPair identityKeyPair) async {
    final key = 'identity_key_pair_$_userId';
    await _storage.write(
      key: key,
      value: base64Encode(identityKeyPair.serialize()),
    );
  }

  Future<void> saveLocalRegistrationId(int registrationId) async {
    final key = 'registration_id_$_userId';
    await _storage.write(key: key, value: registrationId.toString());
  }

  // --- PreKeyStore ---

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    final key = 'pre_key_${_userId}_$preKeyId';
    return await _storage.containsKey(key: key);
  }

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final key = 'pre_key_${_userId}_$preKeyId';
    final value = await _storage.read(key: key);
    if (value == null) {
      throw InvalidKeyIdException('PreKeyRecord not found: $preKeyId');
    }
    return PreKeyRecord.fromBuffer(base64Decode(value));
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    final key = 'pre_key_${_userId}_$preKeyId';
    await _storage.delete(key: key);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    final key = 'pre_key_${_userId}_$preKeyId';
    await _storage.write(key: key, value: base64Encode(record.serialize()));
  }

  // --- SignedPreKeyStore ---

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final key = 'signed_pre_key_${_userId}_$signedPreKeyId';
    return await _storage.containsKey(key: key);
  }

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final key = 'signed_pre_key_${_userId}_$signedPreKeyId';
    final value = await _storage.read(key: key);
    if (value == null) {
      throw InvalidKeyIdException(
        'SignedPreKeyRecord not found: $signedPreKeyId',
      );
    }
    return SignedPreKeyRecord.fromSerialized(base64Decode(value));
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final all = await _storage.readAll();
    final prefix = 'signed_pre_key_${_userId}_';
    return all.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => SignedPreKeyRecord.fromSerialized(base64Decode(e.value)))
        .toList();
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    final key = 'signed_pre_key_${_userId}_$signedPreKeyId';
    await _storage.delete(key: key);
  }

  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) async {
    final key = 'signed_pre_key_${_userId}_$signedPreKeyId';
    await _storage.write(key: key, value: base64Encode(record.serialize()));
  }

  // --- SessionStore ---

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final key = 'session_${_userId}_${address.toString()}';
    return await _storage.containsKey(key: key);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    final all = await _storage.readAll();
    final prefix = 'session_${_userId}_$name';
    for (final key in all.keys) {
      if (key.startsWith(prefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final key = 'session_${_userId}_${address.toString()}';
    await _storage.delete(key: key);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final all = await _storage.readAll();
    final prefix = 'session_${_userId}_$name.';
    return all.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => int.parse(k.split('.').last))
        .toList();
  }

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final key = 'session_${_userId}_${address.toString()}';
    final value = await _storage.read(key: key);
    if (value == null) {
      return SessionRecord();
    }
    return SessionRecord.fromSerialized(base64Decode(value));
  }

  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    final key = 'session_${_userId}_${address.toString()}';
    await _storage.write(key: key, value: base64Encode(record.serialize()));
  }
}
