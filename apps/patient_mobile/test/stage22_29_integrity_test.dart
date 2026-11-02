import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/data/patient_record_repository.dart';
import 'package:ujexa_health/domain/record_integrity.dart';

PatientRecord r(String type,String id,Map<String,dynamic> p)=>PatientRecord(id:id,version:1,resourceType:type,recordedAt:DateTime.utc(2026,1,1),payload:p);
void main(){
 test('flags likely duplicate medication entries',(){
  final report=RecordIntegrity.analyze([
   r('medication_statement','a',{'medication_name':'Drug A','strength':'10 mg','start_date':'2026-01-01'}),
   r('medication_statement','b',{'medication_name':'drug a','strength':'10 mg','start_date':'2026-01-01'}),
  ]);
  expect(report.findings.any((x)=>x.kind=='possible_duplicate'),true);
 });
 test('flags conflicting measurements at same time',(){
  final report=RecordIntegrity.analyze([
   r('observation','a',{'code':'heart_rate','effective_at':'2026-01-01T10:00:00Z','unit':'bpm','value_quantity':70}),
   r('observation','b',{'code':'heart_rate','effective_at':'2026-01-01T10:00:00Z','unit':'bpm','value_quantity':95}),
  ]);
  expect(report.findings.any((x)=>x.kind=='conflicting_measurements'),true);
 });
 test('does not flag different measurement dates',(){
  final report=RecordIntegrity.analyze([
   r('observation','a',{'code':'heart_rate','effective_at':'2026-01-01T10:00:00Z','unit':'bpm','value_quantity':70}),
   r('observation','b',{'code':'heart_rate','effective_at':'2026-01-02T10:00:00Z','unit':'bpm','value_quantity':95}),
  ]);
  expect(report.findings,isEmpty);
 });
}
