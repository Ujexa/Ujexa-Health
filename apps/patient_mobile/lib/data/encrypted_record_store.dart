
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Supplies a vault DEK from the Stage 03 key manager. Implementations must
/// return exactly 32 random key bytes and must never persist/export the key.
abstract interface class VaultDekProvider {
  Future<SecretKey> getVaultDek();
}

/// AES-256-GCM codec. Associated data binds the ciphertext to the record ID
/// and version so ciphertext cannot be transplanted between records.
class AesGcmHealthRecordCodec implements HealthRecordCodec {
  AesGcmHealthRecordCodec(this.dekProvider, {required this.vaultId});
  final VaultDekProvider dekProvider;
  final String vaultId;
  final AesGcm _cipher = AesGcm.with256bits();

  @override
  Future<Uint8List> encrypt(Uint8List plaintext, String recordId, int version) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(plaintext,
      secretKey: await dekProvider.getVaultDek(),
      nonce: nonce,
      aad: _aad(recordId, version));
    return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  @override
  Future<Uint8List> decrypt(Uint8List payload, String recordId, int version) async {
    if (payload.length < 28) throw const FormatException('Encrypted record envelope is truncated');
    final nonce = payload.sublist(0, 12);
    final mac = Mac(payload.sublist(payload.length - 16));
    final cipherText = payload.sublist(12, payload.length - 16);
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: await dekProvider.getVaultDek(),
      aad: _aad(recordId, version));
    return Uint8List.fromList(clear);
  }

  List<int> _aad(String recordId, int version) =>
      'UJEXA_VAULT_V1|record|$vaultId|$recordId|$version'.codeUnits;
}

/// Repository codec abstraction; production uses AesGcmHealthRecordCodec.
abstract interface class HealthRecordCodec {
  Future<Uint8List> encrypt(Uint8List plaintext, String recordId, int version);
  Future<Uint8List> decrypt(Uint8List ciphertext, String recordId, int version);
}

class SqlCipherHealthRecordStore {
  SqlCipherHealthRecordStore({required this.codec, FlutterSecureStorage? secureStorage})
      : secureStorage = secureStorage ?? const FlutterSecureStorage();

  final HealthRecordCodec codec;
  final FlutterSecureStorage secureStorage;
  Database? _database;

  Future<Database> open() async {
    if (_database != null) return _database!;
    const keyName = 'ujexa_health_local_db_key_v1';
    var key = await secureStorage.read(key: keyName);
    if (key == null) {
      final random = math.Random.secure();
      key = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
      await secureStorage.write(key: keyName, value: key);
    }
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, 'ujexa_health_v1.db'),
      password: key,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Clinical type and timestamps are sensitive metadata: remove them
          // from the local index and retain only opaque identifiers/ciphertext.
          // Preserve every encrypted version. Ciphertext is bound to record ID
          // and version through AES-GCM AAD, so copying the bytes is safe.
          // Never discard the v1 table until the copy has completed.
          await db.execute('ALTER TABLE encrypted_records RENAME TO encrypted_records_v1');
          await db.execute('CREATE TABLE encrypted_records (record_id TEXT NOT NULL, version INTEGER NOT NULL, ciphertext BLOB NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(record_id, version))');
          await db.execute('INSERT INTO encrypted_records (record_id, version, ciphertext, deleted) SELECT record_id, version, ciphertext, deleted FROM encrypted_records_v1');
          final oldCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM encrypted_records_v1')) ?? 0;
          final newCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM encrypted_records')) ?? 0;
          if (oldCount != newCount) {
            throw StateError('Encrypted record migration verification failed; refusing to discard the original table.');
          }
          await db.execute('DROP TABLE encrypted_records_v1');
          await db.execute("CREATE TABLE IF NOT EXISTS sync_state (id INTEGER PRIMARY KEY CHECK(id = 1), cursor INTEGER NOT NULL DEFAULT 0)");
          await db.insert('sync_state', {'id': 1, 'cursor': 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      },
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE encrypted_records (record_id TEXT NOT NULL, version INTEGER NOT NULL, ciphertext BLOB NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(record_id, version))');
        await db.execute('CREATE TABLE sync_state (id INTEGER PRIMARY KEY CHECK(id = 1), cursor INTEGER NOT NULL DEFAULT 0)');
        await db.insert('sync_state', {'id': 1, 'cursor': 0});
      },
    );
    return _database!;
  }

  Future<void> save({
    required String recordId,
    required int version,
    required Uint8List plaintextJson,
  }) async {
    final db = await open();
    final ciphertext = await codec.encrypt(plaintextJson, recordId, version);
    await db.insert('encrypted_records', {
      'record_id': recordId, 'version': version,
      'ciphertext': ciphertext, 'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<Uint8List?> read(String recordId, {int? version}) async {
    final db = await open();
    final rows = await db.query('encrypted_records',
      where: version == null ? 'record_id = ? AND deleted = 0' : 'record_id = ? AND version = ? AND deleted = 0',
      whereArgs: version == null ? [recordId] : [recordId, version],
      orderBy: 'version DESC', limit: 1);
    if (rows.isEmpty) return null;
    return codec.decrypt(Uint8List.fromList(rows.first['ciphertext'] as List<int>),
      recordId, rows.first['version'] as int);
  }

  Future<List<Map<String, Object?>>> listOpaqueMetadata() async {
    final db = await open();
    return db.query('encrypted_records',
      columns: ['record_id', 'version', 'deleted'],
      orderBy: 'record_id, version DESC');
  }

  Future<void> addTombstone(String recordId) async {
    final db = await open();
    await db.update('encrypted_records', {'deleted': 1},
      where: 'record_id = ?', whereArgs: [recordId]);
  }

  Future<int> readSyncCursor() async {
    final db = await open();
    final rows = await db.query('sync_state', columns: ['cursor'], where: 'id = 1');
    return rows.first['cursor'] as int;
  }

  Future<void> writeSyncCursor(int cursor) async {
    final db = await open();
    await db.update('sync_state', {'cursor': cursor}, where: 'id = 1');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
