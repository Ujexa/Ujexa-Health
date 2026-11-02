import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/domain/document_understanding.dart';

void main(){
 group('Stage 20 structured extraction candidates',(){
  test('extracts a named lab value and nearby reference range',(){
   final r=DocumentUnderstandingEngine.analyze('[Page 3]\nHaemoglobin: 13.5 g/dL Reference range: 12.0 - 16.0 g/dL');
   final c=r.structuredCandidates.firstWhere((x)=>x.kind=='lab_result_candidate');
   expect(c.fields['test_name'],'Haemoglobin');
   expect(c.fields['value'],'13.5 g/dL');
   expect(c.fields['reference_range'],isNotNull);
   expect(c.page,3);
  });
  test('extracts prescription instruction candidate without inferring schedule',(){
   final r=DocumentUnderstandingEngine.analyze('Prescription\nTake one tablet');
   final c=r.structuredCandidates.firstWhere((x)=>x.kind=='medication_instruction_candidate');
   expect(c.fields['instruction_text'],'Take one tablet');
   expect(c.fields.containsKey('dose_times'),false);
  });
  test('extracts date text without silently normalizing it',(){
   final r=DocumentUnderstandingEngine.analyze('Date: 03/11/2026');
   final c=r.structuredCandidates.firstWhere((x)=>x.kind=='document_date_candidate');
   expect(c.fields['date_text'],'03/11/2026');
  });
  test('empty document produces no structured candidates',(){
   expect(DocumentUnderstandingEngine.analyze('').structuredCandidates,isEmpty);
  });
 });
}
