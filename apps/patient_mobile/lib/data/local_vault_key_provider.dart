
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'encrypted_record_store.dart';

/// Development bridge only. Production must obtain the DEK from the Stage 03
/// envelope/key manager, with recovery, rotation and device revocation support.
class SecureStorageVaultDekProvider implements VaultDekProvider {
  SecureStorageVaultDekProvider({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _keyName = 'ujexa_health_vault_dek_dev_v1';

  @override
  Future<SecretKey> getVaultDek() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final random = math.Random.secure();
      encoded = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      await _storage.write(key: _keyName, value: encoded);
    }
    final bytes = base64Url.decode(base64Url.normalize(encoded));
    if (bytes.length != 32) {
      throw StateError('Stored vault key has an invalid length');
    }
    return SecretKey(bytes);
  }
}
