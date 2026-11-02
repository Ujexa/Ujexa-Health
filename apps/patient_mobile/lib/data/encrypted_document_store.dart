
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'encrypted_record_store.dart';

/// Stores document bytes only after encryption. Filenames on disk are opaque IDs.
class EncryptedDocumentStore {
  EncryptedDocumentStore(this.codec);
  final HealthRecordCodec codec;
  static const _uuid = Uuid();

  Future<String> save(Uint8List clearBytes) async {
    if (clearBytes.isEmpty) throw const FormatException('Selected document is empty');
    final id = _uuid.v4();
    final encrypted = await codec.encrypt(clearBytes, id, 1);
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'ujexa_documents'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '$id.ujx'));
    await file.writeAsBytes(encrypted, flush: true);
    return id;
  }

  Future<Uint8List> read(String blobId) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(blobId)) {
      throw const FormatException('Invalid encrypted document reference');
    }
    final root = await getApplicationSupportDirectory();
    final file = File(p.join(root.path, 'ujexa_documents', '$blobId.ujx'));
    if (!await file.exists()) throw const FileSystemException('Encrypted document not found');
    final encrypted = await file.readAsBytes();
    return codec.decrypt(Uint8List.fromList(encrypted), blobId, 1);
  }

  Future<void> delete(String blobId) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(blobId)) return;
    final root = await getApplicationSupportDirectory();
    final file = File(p.join(root.path, 'ujexa_documents', '$blobId.ujx'));
    if (await file.exists()) await file.delete();
  }
}
