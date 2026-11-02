import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/domain/document_understanding.dart';

void main(){
 group('DocumentUnderstandingEngine',(){
  test('suggests lab report from relevant terminology',(){
   final r=DocumentUnderstandingEngine.analyze('Laboratory result\\nHaemoglobin\\nReference range\\nGlucose');
   expect(r.suggestedType,'lab_report');
  });
  test('suggests prescription from prescription terms',(){
   final r=DocumentUnderstandingEngine.analyze('Prescription\\nTake one tablet daily\\nRefills');
   expect(r.suggestedType,'prescription');
  });
  test('extracts measurement candidates with evidence and page number',(){
   final r=DocumentUnderstandingEngine.analyze('[Page 2]\\nHaemoglobin 13.5 g/dL');
   expect(r.candidates,hasLength(1));
   expect(r.candidates.single.value,'13.5 g/dL');
   expect(r.candidates.single.page,2);
   expect(r.candidates.single.evidence,contains('Haemoglobin'));
  });
  test('does not invent classification for empty text',(){
   final r=DocumentUnderstandingEngine.analyze('');
   expect(r.suggestedType,'other');
   expect(r.typeConfidence,0);
   expect(r.candidates,isEmpty);
  });
 });
}
