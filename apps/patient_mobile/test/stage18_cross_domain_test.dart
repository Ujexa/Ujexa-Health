import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/data/patient_record_repository.dart';
import 'package:ujexa_health/domain/cross_domain_health_intelligence.dart';

PatientRecord record(String type,String id,Map<String,dynamic> payload,String date)=>
  PatientRecord(id:id,version:1,resourceType:type,recordedAt:DateTime.parse(date),payload:payload);

void main(){
  group('CrossDomainHealthIntelligence',(){
    test('finds symptom and measurement within the 24-hour window',(){
      final result=CrossDomainHealthIntelligence.analyze([
        record('symptom_entry','s1',{'symptom_name':'Headache','occurred_at':'2026-10-01T10:00:00Z'},'2026-10-01T10:00:00Z'),
        record('observation','o1',{'display':'Heart rate','effective_at':'2026-10-01T08:00:00Z'},'2026-10-01T08:00:00Z'),
      ]);
      expect(result.relationships,hasLength(1));
      expect(result.relationships.single.kind,'symptom_observation');
      expect(result.relationships.single.sourceRecordIds,containsAll(['s1','o1']));
    });
    test('does not link records outside the temporal window',(){
      final result=CrossDomainHealthIntelligence.analyze([
        record('symptom_entry','s1',{'symptom_name':'Headache','occurred_at':'2026-10-01T10:00:00Z'},'2026-10-01T10:00:00Z'),
        record('observation','o1',{'display':'Heart rate','effective_at':'2026-10-03T10:01:00Z'},'2026-10-03T10:01:00Z'),
      ]);
      expect(result.relationships,isEmpty);
    });
    test('finds medication and journal overlaps separately',(){
      final result=CrossDomainHealthIntelligence.analyze([
        record('symptom_entry','s1',{'symptom_name':'Nausea','occurred_at':'2026-10-01T10:00:00Z'},'2026-10-01T10:00:00Z'),
        record('medication_dose_log','m1',{'event_type':'taken','occurred_at':'2026-10-01T09:30:00Z'},'2026-10-01T09:30:00Z'),
        record('health_journal','j1',{'entry_text':'Felt unwell'},'2026-10-01T12:00:00Z'),
      ]);
      expect(result.relationships.map((r)=>r.kind),containsAll(['symptom_medication','symptom_journal']));
    });
    test('uses explicit encounter links for visit measurements',(){
      final result=CrossDomainHealthIntelligence.analyze([
        record('encounter','e1',{'started_at':'2026-10-01T09:00:00Z'},'2026-10-01T09:00:00Z'),
        record('observation','o1',{'display':'Blood pressure','encounter_id':'e1'},'2026-10-01T09:10:00Z'),
      ]);
      expect(result.relationships.single.kind,'encounter_observation');
    });
    test('document overlap is date-level only',(){
      final result=CrossDomainHealthIntelligence.analyze([
        record('document_reference','d1',{'title':'Lab report','document_date':'2026-10-01'},'2026-10-01T12:00:00Z'),
        record('symptom_entry','s1',{'symptom_name':'Fatigue','occurred_at':'2026-10-01T07:00:00Z'},'2026-10-01T07:00:00Z'),
      ]);
      expect(result.relationships.single.kind,'document_overlap');
      expect(result.relationships.single.description,contains('not been interpreted'));
    });
  });
}
