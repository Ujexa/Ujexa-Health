import '../data/patient_record_repository.dart';

class HealthRelationship {
  const HealthRelationship({
    required this.title,
    required this.description,
    required this.eventCount,
    required this.sourceRecordIds,
    required this.firstAt,
    required this.latestAt,
    required this.kind,
  });
  final String title;
  final String description;
  final int eventCount;
  final List<String> sourceRecordIds;
  final DateTime firstAt;
  final DateTime latestAt;
  final String kind;
}

class CrossDomainSnapshot {
  const CrossDomainSnapshot({
    required this.relationships,
    required this.symptomEpisodesCompared,
    required this.observationsCompared,
    required this.medicationEventsCompared,
    required this.encountersCompared,
    required this.documentsCompared,
    required this.notes,
  });
  final List<HealthRelationship> relationships;
  final int symptomEpisodesCompared;
  final int observationsCompared;
  final int medicationEventsCompared;
  final int encountersCompared;
  final int documentsCompared;
  final List<String> notes;
}

/// Deterministic temporal co-occurrence analysis. It does not infer causation,
/// clinical significance, medication effects or disease risk.
class CrossDomainHealthIntelligence {
  static const Duration window = Duration(hours: 24);

  static CrossDomainSnapshot analyze(List<PatientRecord> records) {
    DateTime at(PatientRecord r) {
      final raw = switch (r.resourceType) {
        'symptom_entry' => r.payload['occurred_at'],
        'observation' => r.payload['effective_at'],
        'medication_dose_log' => r.payload['occurred_at'],
        'encounter' => r.payload['started_at'],
        'document_reference' => r.payload['document_date'],
        'health_journal' => r.recordedAt.toIso8601String(),
        _ => r.recordedAt.toIso8601String(),
      };
      return DateTime.tryParse(raw?.toString() ?? '')?.toUtc() ?? r.recordedAt.toUtc();
    }

    final symptoms = records.where((r)=>r.resourceType=='symptom_entry').toList();
    final observations = records.where((r)=>r.resourceType=='observation').toList();
    final doseEvents = records.where((r)=>r.resourceType=='medication_dose_log').toList();
    final encounters = records.where((r)=>r.resourceType=='encounter').toList();
    final documents = records.where((r)=>r.resourceType=='document_reference').toList();
    final journals = records.where((r)=>r.resourceType=='health_journal').toList();

    final relationships=<HealthRelationship>[];
    final used=<String>{};

    void add({
      required String kind,
      required String title,
      required String description,
      required List<PatientRecord> rows,
    }) {
      if (rows.isEmpty) return;
      final sorted=rows.toList()..sort((a,b)=>at(a).compareTo(at(b)));
      final ids=sorted.map((r)=>r.id).toSet().toList();
      final signature='$kind:${ids.join("|")}';
      if (!used.add(signature)) return;
      relationships.add(HealthRelationship(
        title:title,
        description:description,
        eventCount:sorted.length,
        sourceRecordIds:List.unmodifiable(ids),
        firstAt:at(sorted.first),
        latestAt:at(sorted.last),
        kind:kind,
      ));
    }

    // For each symptom, show observations recorded within ±24 hours.
    for (final symptom in symptoms) {
      final time=at(symptom);
      final nearby=observations.where((o)=>at(o).difference(time).abs()<=window).toList();
      if (nearby.isNotEmpty) {
        add(kind:'symptom_observation',
          title:'${symptom.payload['symptom_name'] ?? 'Symptom'} and nearby measurements',
          description:'${nearby.length} measurement(s) were recorded within 24 hours before or after this symptom entry. This is timing overlap, not evidence of a relationship.',
          rows:[symptom,...nearby]);
      }
      final nearbyDoses=doseEvents.where((d)=>at(d).difference(time).abs()<=window).toList();
      if (nearbyDoses.isNotEmpty) {
        add(kind:'symptom_medication',
          title:'${symptom.payload['symptom_name'] ?? 'Symptom'} and nearby medication events',
          description:'${nearbyDoses.length} patient-reported dose event(s) occurred within 24 hours before or after this symptom entry. This does not indicate a medication effect.',
          rows:[symptom,...nearbyDoses]);
      }
      final nearbyJournal=journals.where((j)=>at(j).difference(time).abs()<=window).toList();
      if (nearbyJournal.isNotEmpty) {
        add(kind:'symptom_journal',
          title:'Symptom and nearby journal entries',
          description:'${nearbyJournal.length} journal entry(ies) were recorded within 24 hours of this symptom entry.',
          rows:[symptom,...nearbyJournal]);
      }
      final nearbyVisits=encounters.where((e)=>at(e).difference(time).abs()<=window).toList();
      if (nearbyVisits.isNotEmpty) {
        add(kind:'symptom_encounter',
          title:'Symptom and nearby checkup / visit',
          description:'A symptom entry and ${nearbyVisits.length} visit record(s) fall within the same 24-hour comparison window.',
          rows:[symptom,...nearbyVisits]);
      }
    }

    // Link measurements to visits when explicit observation encounter_id exists.
    for (final encounter in encounters) {
      final linked=observations.where((o)=>o.payload['encounter_id']==encounter.id).toList();
      if (linked.isNotEmpty) {
        add(kind:'encounter_observation',
          title:'Visit with linked measurements',
          description:'${linked.length} measurement(s) are explicitly linked to this visit record.',
          rows:[encounter,...linked]);
      }
    }

    // Document dates can overlap with other records, but this is only a date-level
    // clue: the document may refer to a different event or historical period.
    for (final document in documents) {
      final raw=document.payload['document_date'];
      final docDate=DateTime.tryParse(raw?.toString() ?? '');
      if (docDate==null) continue;
      final sameDay=records.where((r)=>r.id!=document.id &&
        {'symptom_entry','observation','medication_dose_log','encounter','health_journal'}.contains(r.resourceType) &&
        at(r).year==docDate.year && at(r).month==docDate.month && at(r).day==docDate.day).toList();
      if (sameDay.isNotEmpty) {
        add(kind:'document_overlap',
          title:'Document and same-date health entries',
          description:'${sameDay.length} record(s) share the document date. The document content has not been interpreted or clinically matched to them.',
          rows:[document,...sameDay]);
      }
    }

    relationships.sort((a,b)=>b.latestAt.compareTo(a.latestAt));
    final notes=[
      'Comparisons use a fixed ±24-hour window for symptom co-occurrence; document comparisons use calendar dates.',
      'A time overlap is not proof of cause, effect, medication interaction or clinical significance.',
      'Only records with usable dates can contribute. Missing or imprecise dates may hide relationships.',
      'All source records remain patient-reported or imported with their original provenance.',
    ];
    return CrossDomainSnapshot(
      relationships:List.unmodifiable(relationships),
      symptomEpisodesCompared:symptoms.length,
      observationsCompared:observations.length,
      medicationEventsCompared:doseEvents.length,
      encountersCompared:encounters.length,
      documentsCompared:documents.length,
      notes:List.unmodifiable(notes),
    );
  }
}
