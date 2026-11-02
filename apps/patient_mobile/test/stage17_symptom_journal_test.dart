import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/data/patient_record_repository.dart';
import 'package:ujexa_health/domain/symptom_journal_intelligence.dart';

PatientRecord record(String type, String id, Map<String,dynamic> payload, String date) =>
  PatientRecord(id:id,version:1,resourceType:type,recordedAt:DateTime.parse(date),payload:payload);

void main() {
  group('SymptomJournalIntelligence', () {
    test('groups symptom entries and calculates descriptive severity', () {
      final result=SymptomJournalIntelligence.analyze([
        record('symptom_entry','s1',{'symptom_name':'Headache','severity':4,'possible_triggers':['poor sleep']},'2026-10-01T10:00:00Z'),
        record('symptom_entry','s2',{'symptom_name':'headache','severity':8,'possible_triggers':['poor sleep','stress']},'2026-10-03T10:00:00Z'),
      ]);
      expect(result.patterns,hasLength(1));
      expect(result.patterns.single.episodes,2);
      expect(result.patterns.single.averageSeverity,6);
      expect(result.patterns.single.highestSeverity,8);
      expect(result.patterns.single.commonTriggers.first,'poor sleep');
    });
    test('summarizes journal scores without mixing in symptom records', () {
      final result=SymptomJournalIntelligence.analyze([
        record('health_journal','j1',{'entry_text':'Entry','mood_score':4,'energy_score':2,'stress_score':3},'2026-10-01T10:00:00Z'),
        record('health_journal','j2',{'entry_text':'Entry 2','mood_score':2,'energy_score':4,'stress_score':5},'2026-10-01T20:00:00Z'),
      ]);
      expect(result.journalEntries,2);
      expect(result.averageMood,3);
      expect(result.averageEnergy,3);
      expect(result.averageStress,4);
      expect(result.daysWithEntries,1);
      expect(result.patterns,isEmpty);
    });
    test('returns explicit empty-data notes', () {
      final result=SymptomJournalIntelligence.analyze([]);
      expect(result.patterns,isEmpty);
      expect(result.notes,isNotEmpty);
    });
  });
}
