
import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/domain/longitudinal_health_network.dart';
import 'package:ujexa_health/domain/medication_adherence.dart';
import 'package:ujexa_health/data/patient_record_repository.dart';

PatientRecord record(String id,String type,DateTime at,Map<String,dynamic> fields)=>PatientRecord(
  id:id,version:1,resourceType:type,recordedAt:at,payload:fields);

void main(){
  group('LongitudinalHealthNetwork',(){
    test('waits for sufficient history rather than inventing a baseline',(){
      final records=[record('a','observation',DateTime(2026,1,1),{
        'code':'heart_rate','value_quantity':72,'effective_at':'2026-01-01T08:00:00Z'
      })];
      final result=LongitudinalHealthNetwork().analyze(records);
      expect(result.ready,isFalse);
      expect(result.historyDays,1);
    });
    test('trains a temporal personal baseline when history is sufficient',(){
      final records=<PatientRecord>[];
      for(var i=0;i<25;i++){
        final d=DateTime(2026,1,1+i);
        records.add(record('obs-$i','observation',d,{
          'code':'heart_rate','value_quantity':70+(i%3),'effective_at':d.toUtc().toIso8601String()
        }));
      }
      final result=LongitudinalHealthNetwork().analyze(records);
      expect(result.ready,isTrue);
      expect(result.trainingDays,greaterThanOrEqualTo(12));
      expect(result.evaluatedDays,greaterThan(0));
      expect(result.summary,isNotEmpty);
    });
  });
  group('MedicationAdherenceEngine',(){
    test('counts dose events and leaves unconfirmed overdue doses unresolved',(){
      final now=DateTime(2026,5,5,12);
      final med=record('med-1','medication_statement',now,{
        'medication_name':'Example','dose':'1 tablet','status':'active',
        'dose_times':['08:00','20:00'],'start_date':'2026-05-01'
      });
      final taken=record('log-1','medication_dose_log',DateTime(2026,5,5,8),{
        'medication_record_id':'med-1','event_type':'taken',
        'occurred_at':'2026-05-05T08:00:00'
      });
      final result=MedicationAdherenceEngine.analyze([med,taken],now:now,days:1);
      expect(result.taken,1);
      expect(result.overdue,0); // 20:00 is upcoming; no automatic missed event.
      expect(result.adherencePercent,100);
    });
  });
}
