
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'encrypted_record_store.dart';

/// A decrypted record exists only in memory after reading from the encrypted store.
class PatientRecord {
  const PatientRecord({
    required this.id,
    required this.version,
    required this.resourceType,
    required this.recordedAt,
    required this.payload,
  });

  final String id;
  final int version;
  final String resourceType;
  final DateTime recordedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    ...payload,
    'resource_type': resourceType,
    'resource_id': id,
    'version': version,
    'provenance': payload['provenance'] ?? {
      'source': 'patient',
      'verification_status': 'unverified',
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    },
  };

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
    id: json['resource_id'] as String,
    version: json['version'] as int,
    resourceType: json['resource_type'] as String,
    recordedAt: DateTime.parse(
      (json['provenance'] as Map<String, dynamic>)['recorded_at'] as String,
    ),
    payload: json,
  );
}

/// Typed application boundary over the encrypted SQLCipher store.
/// The repository serializes canonical resource JSON before encryption.
class PatientRecordRepository {
  PatientRecordRepository(this.store);

  final SqlCipherHealthRecordStore store;
  static const _uuid = Uuid();

  Future<PatientRecord> create({
    required String resourceType,
    required Map<String, dynamic> fields,
    DateTime? recordedAt,
  }) async {
    _validateResource(resourceType, fields);
    final now = recordedAt ?? DateTime.now().toUtc();
    final record = PatientRecord(
      id: _uuid.v4(),
      version: 1,
      resourceType: resourceType,
      recordedAt: now,
      payload: fields,
    );
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(record.toJson())));
    await store.save(
      recordId: record.id,
      version: record.version,
      plaintextJson: bytes,
    );
    return record;
  }

  Future<PatientRecord?> read(String id, {int? version}) async {
    final clear = await store.read(id, version: version);
    if (clear == null) return null;
    final decoded = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    return PatientRecord.fromJson(decoded);
  }

  Future<List<PatientRecord>> readAll() async {
    final metadata = await store.listOpaqueMetadata();
    final latest = <String, Map<String, Object?>>{};
    for (final row in metadata) {
      final id = row['record_id'] as String;
      final previous = latest[id];
      if (previous == null || (row['version'] as int) > (previous['version'] as int)) {
        latest[id] = row;
      }
    }
    final records = <PatientRecord>[];
    for (final row in latest.values) {
      if ((row['deleted'] as int) == 1) continue;
      final clear = await store.read(
        row['record_id'] as String,
        version: row['version'] as int,
      );
      if (clear == null) continue;
      final decoded = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      records.add(PatientRecord.fromJson(decoded));
    }
    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return List.unmodifiable(records);
  }

  Future<void> delete(PatientRecord record) => store.addTombstone(record.id);

  Future<PatientRecord> update(
    PatientRecord previous, {
    required Map<String, dynamic> fields,
  }) async {
    _validateResource(previous.resourceType, fields);
    final next = PatientRecord(
      id: previous.id,
      version: previous.version + 1,
      resourceType: previous.resourceType,
      recordedAt: DateTime.now().toUtc(),
      payload: fields,
    );
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(next.toJson())));
    await store.save(
      recordId: next.id,
      version: next.version,
      plaintextJson: bytes,
    );
    return next;
  }
}


void _validateResource(String type, Map<String, dynamic> fields) {
  void requiredText(String key) {
    final value = fields[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key is required for $type');
    }
  }

  const encounterTypes = {
    'routine_checkup', 'follow_up', 'urgent_care', 'emergency',
    'specialist_visit', 'telehealth', 'other',
  };
  const conditionStatuses = {
    'active', 'resolved', 'inactive', 'in_remission', 'unknown',
  };
  const allergySeverities = {'mild', 'moderate', 'severe', 'unknown'};
  const allergyStatuses = {'active', 'inactive', 'entered_in_error', 'unknown'};
  const medicationStatuses = {'active', 'on_hold', 'completed', 'stopped', 'unknown'};

  const symptomAreas = {'general','head','chest','abdomen','back','muscles','joints','skin','breathing','digestive','other'};
  if (type == 'symptom_entry') {
    requiredText('symptom_name');
    requiredText('occurred_at');
    final severity = fields['severity'];
    if (severity is! int || severity < 1 || severity > 10) {
      throw const FormatException('Symptom severity must be an integer from 1 to 10');
    }
    if (!symptomAreas.contains(fields['body_area'])) {
      throw const FormatException('Unsupported symptom body area');
    }
    if (fields['possible_triggers'] != null && fields['possible_triggers'] is! List) {
      throw const FormatException('possible_triggers must be a list');
    }
    return;
  }
  if (type == 'health_journal') {
    requiredText('entry_text');
    for (final key in ['mood_score','energy_score','stress_score']) {
      final value = fields[key];
      if (value != null && (value is! int || value < 1 || value > 5)) {
        throw FormatException('$key must be an integer from 1 to 5');
      }
    }
    return;
  }

  if (type == 'appointment') {
    requiredText('title'); requiredText('appointment_at'); return;
  }
  if (type == 'lifestyle_entry') {
    requiredText('category'); requiredText('occurred_at'); requiredText('summary');
    if (!{'nutrition','activity','sleep','hydration','other'}.contains(fields['category'])) throw const FormatException('Unsupported lifestyle category');
    return;
  }
  if (type == 'preventive_care') {
    requiredText('item');
    if (!{'due','scheduled','completed','not_applicable','unknown'}.contains(fields['status'])) throw const FormatException('Unsupported preventive-care status');
    return;
  }
  if (type == 'sharing_consent') {
    requiredText('recipient'); requiredText('purpose');
    if (fields['included_categories'] is! List || (fields['included_categories'] as List).isEmpty) throw const FormatException('Select at least one sharing category');
    if (!{'active','revoked','expired'}.contains(fields['status'])) throw const FormatException('Unsupported consent status');
    return;
  }

  switch (type) {
    case 'patient_profile':
      if (fields['blood_group'] != null && !{
        'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown', 'not_recorded',
      }.contains(fields['blood_group'])) {
        throw const FormatException('Unsupported blood group');
      }
      break;
    case 'medication_dose_log':
      requiredText('medication_record_id');
      requiredText('occurred_at');
      if (!{'taken', 'missed', 'skipped', 'unknown'}.contains(fields['event_type'])) {
        throw const FormatException('Unsupported medication event type');
      }
      break;
    case 'document_reference':
      requiredText('document_type');
      requiredText('title');
      requiredText('media_type');
      requiredText('encrypted_blob_id');
      if (!{
        'lab_report', 'prescription', 'discharge_summary', 'imaging_report',
        'referral', 'vaccination_record', 'insurance', 'other',
      }.contains(fields['document_type'])) {
        throw const FormatException('Unsupported document type');
      }
      break;
    case 'encounter':
      requiredText('encounter_type');
      requiredText('status');
      requiredText('started_at');
      if (!encounterTypes.contains(fields['encounter_type'])) {
        throw const FormatException('Unsupported encounter type');
      }
      if (fields['related_observation_ids'] is! List) {
        throw const FormatException('related_observation_ids must be a list');
      }
      break;
    case 'observation':
      requiredText('code');
      requiredText('display');
      requiredText('effective_at');
      if (fields['value_quantity'] is! num && fields['value_text'] is! String) {
        throw const FormatException('An observation needs a numeric or text value');
      }
      break;
    case 'medication_statement':
      requiredText('medication_name');
      if (!medicationStatuses.contains(fields['status'])) {
        throw const FormatException('Unsupported medication status');
      }
      break;
    case 'allergy':
      requiredText('substance');
      if (!allergySeverities.contains(fields['severity']) ||
          !allergyStatuses.contains(fields['status'])) {
        throw const FormatException('Unsupported allergy severity or status');
      }
      break;
    case 'condition':
      requiredText('display');
      if (!conditionStatuses.contains(fields['status'])) {
        throw const FormatException('Unsupported condition status');
      }
      break;
    default:
      throw FormatException('Unsupported patient resource type: $type');
  }
}
