/// Ujexa Health canonical patient-owned record contracts.
///
/// These types describe the plaintext domain model after client-side decryption.
/// They are not API wire payloads: the server stores encrypted record envelopes.
enum ProvenanceSource { patient, clinician, importedDocument, device, application }
enum VerificationStatus { unverified, patientConfirmed, clinicianVerified }
enum HealthRecordType {
  patientProfile, condition, allergy, procedure, encounter,
  observation, medicationStatement, medicationDoseLog, documentReference,
}

class RecordProvenance {
  const RecordProvenance({
    required this.source,
    required this.verificationStatus,
    required this.recordedAt,
    this.recordedBy,
    this.organization,
    this.sourceDocumentId,
    this.sourceReference,
    this.notes,
  });

  final ProvenanceSource source;
  final VerificationStatus verificationStatus;
  final DateTime recordedAt;
  final String? recordedBy;
  final String? organization;
  final String? sourceDocumentId;
  final String? sourceReference;
  final String? notes;
}

abstract class HealthRecord {
  String get resourceId;
  int get version;
  HealthRecordType get type;
  DateTime get recordedAt;
  RecordProvenance get provenance;
}

class HealthCondition implements HealthRecord {
  const HealthCondition({
    required this.resourceId,
    required this.version,
    required this.display,
    required this.status,
    required this.provenance,
    this.onsetDate,
    this.resolutionDate,
    this.clinicalCodeSystem,
    this.clinicalCode,
    this.notes,
  });

  @override final String resourceId;
  @override final int version;
  final String display;
  final String status;
  final DateTime? onsetDate;
  final DateTime? resolutionDate;
  final String? clinicalCodeSystem;
  final String? clinicalCode;
  final String? notes;
  @override final RecordProvenance provenance;
  @override HealthRecordType get type => HealthRecordType.condition;
  @override DateTime get recordedAt => provenance.recordedAt;
}

class HealthAllergy implements HealthRecord {
  const HealthAllergy({
    required this.resourceId,
    required this.version,
    required this.substance,
    required this.severity,
    required this.status,
    required this.provenance,
    this.reaction,
    this.onsetDate,
    this.notes,
  });

  @override final String resourceId;
  @override final int version;
  final String substance;
  final String severity;
  final String status;
  final String? reaction;
  final DateTime? onsetDate;
  final String? notes;
  @override final RecordProvenance provenance;
  @override HealthRecordType get type => HealthRecordType.allergy;
  @override DateTime get recordedAt => provenance.recordedAt;
}

class HealthEncounter implements HealthRecord {
  const HealthEncounter({
    required this.resourceId,
    required this.version,
    required this.encounterType,
    required this.status,
    required this.startedAt,
    required this.provenance,
    this.endedAt,
    this.providerName,
    this.organization,
    this.location,
    this.reason,
    this.clinicalNotes,
    this.followUpInstructions,
    this.relatedObservationIds = const [],
  });

  @override final String resourceId;
  @override final int version;
  final String encounterType;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? providerName;
  final String? organization;
  final String? location;
  final String? reason;
  final String? clinicalNotes;
  final String? followUpInstructions;
  final List<String> relatedObservationIds;
  @override final RecordProvenance provenance;
  @override HealthRecordType get type => HealthRecordType.encounter;
  @override DateTime get recordedAt => provenance.recordedAt;
}

class HealthObservation implements HealthRecord {
  const HealthObservation({
    required this.resourceId,
    required this.version,
    required this.code,
    required this.display,
    required this.effectiveAt,
    required this.provenance,
    this.valueQuantity,
    this.unit,
    this.valueText,
    this.components = const {},
    this.bodySite,
    this.method,
    this.encounterId,
    this.notes,
  });

  @override final String resourceId;
  @override final int version;
  final String code;
  final String display;
  final DateTime effectiveAt;
  final double? valueQuantity;
  final String? unit;
  final String? valueText;
  final Map<String, Object> components;
  final String? bodySite;
  final String? method;
  final String? encounterId;
  final String? notes;
  @override final RecordProvenance provenance;
  @override HealthRecordType get type => HealthRecordType.observation;
  @override DateTime get recordedAt => provenance.recordedAt;
}

/// Implementations must encrypt before persistence and decrypt only on-device.
/// Implementations must never send plaintext records or DEKs to the API.
abstract interface class EncryptedHealthRecordRepository {
  Future<void> save(HealthRecord record);
  Future<HealthRecord?> read(String resourceId, {int? version});
  Future<List<HealthRecord>> readAll();
  Future<void> delete(String resourceId, {int? version});
}

/// Timeline ordering is performed on decrypted records on the trusted client.
/// The server's record index intentionally does not expose clinical dates/types.
List<HealthRecord> buildHealthTimeline(Iterable<HealthRecord> records) {
  final result = records.toList()
    ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  return List.unmodifiable(result);
}
