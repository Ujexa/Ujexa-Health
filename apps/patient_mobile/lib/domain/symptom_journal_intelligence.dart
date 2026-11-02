import '../data/patient_record_repository.dart';

class SymptomPattern {
  const SymptomPattern({
    required this.name,
    required this.episodes,
    required this.averageSeverity,
    required this.latestAt,
    required this.highestSeverity,
    required this.commonTriggers,
  });
  final String name;
  final int episodes;
  final double averageSeverity;
  final DateTime latestAt;
  final int highestSeverity;
  final List<String> commonTriggers;
}

class SymptomJournalSnapshot {
  const SymptomJournalSnapshot({
    required this.patterns,
    required this.journalEntries,
    required this.averageMood,
    required this.averageEnergy,
    required this.averageStress,
    required this.daysWithEntries,
    required this.notes,
  });
  final List<SymptomPattern> patterns;
  final int journalEntries;
  final double? averageMood;
  final double? averageEnergy;
  final double? averageStress;
  final int daysWithEntries;
  final List<String> notes;
}

/// Descriptive aggregation only. It does not infer causes, diagnoses or risk.
class SymptomJournalIntelligence {
  static SymptomJournalSnapshot analyze(List<PatientRecord> records) {
    final symptoms = records.where((r) => r.resourceType == 'symptom_entry').toList();
    final journals = records.where((r) => r.resourceType == 'health_journal').toList();
    final grouped = <String,List<PatientRecord>>{};
    for (final record in symptoms) {
      final name = (record.payload['symptom_name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      grouped.putIfAbsent(name.toLowerCase(), () => []).add(record);
    }
    final patterns = <SymptomPattern>[];
    for (final rows in grouped.values) {
      rows.sort((a,b) => a.recordedAt.compareTo(b.recordedAt));
      final severities = rows.map((r) => r.payload['severity']).whereType<num>().map((n)=>n.toDouble()).toList();
      final triggerCounts = <String,int>{};
      for (final row in rows) {
        final triggers = row.payload['possible_triggers'];
        if (triggers is List) {
          for (final trigger in triggers.whereType<String>()) {
            final clean = trigger.trim();
            if (clean.isNotEmpty) triggerCounts.update(clean,(v)=>v+1,ifAbsent:()=>1);
          }
        }
      }
      final first = rows.first;
      patterns.add(SymptomPattern(
        name: (first.payload['symptom_name'] ?? 'Symptom').toString(),
        episodes: rows.length,
        averageSeverity: severities.isEmpty ? 0 : severities.reduce((a,b)=>a+b)/severities.length,
        latestAt: rows.last.recordedAt,
        highestSeverity: severities.isEmpty ? 0 : severities.reduce((a,b)=>a>b?a:b).round(),
        commonTriggers: (triggerCounts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).map((e)=>e.key).toList(),
      ));
    }
    patterns.sort((a,b)=>b.episodes.compareTo(a.episodes));
    double? average(String key) {
      final values=journals.map((r)=>r.payload[key]).whereType<num>().map((v)=>v.toDouble()).toList();
      return values.isEmpty?null:values.reduce((a,b)=>a+b)/values.length;
    }
    final days=journals.map((r) {
      final d=r.recordedAt.toLocal();
      return '${d.year}-${d.month}-${d.day}';
    }).toSet();
    final notes=<String>[];
    if (symptoms.isEmpty) notes.add('No symptom episodes have been recorded yet.');
    if (journals.isEmpty) notes.add('No journal entries have been recorded yet.');
    notes.add('Patterns describe recorded entries only. They do not establish causes or medical significance.');
    return SymptomJournalSnapshot(
      patterns: List.unmodifiable(patterns),
      journalEntries: journals.length,
      averageMood: average('mood_score'),
      averageEnergy: average('energy_score'),
      averageStress: average('stress_score'),
      daysWithEntries: days.length,
      notes: List.unmodifiable(notes),
    );
  }
}
