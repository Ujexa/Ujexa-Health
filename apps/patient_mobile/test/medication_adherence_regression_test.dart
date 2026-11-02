import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/data/patient_record_repository.dart';
import 'package:ujexa_health/domain/medication_adherence.dart';

PatientRecord record(String id, String type, Map<String, dynamic> payload, DateTime at) =>
    PatientRecord(id: id, version: 1, resourceType: type, recordedAt: at, payload: payload);

void main() {
  group('Medication adherence matching', () {
    final day = DateTime(2026, 11, 2, 15);
    test('one dose event cannot satisfy two scheduled doses', () {
      final med = record('med-1', 'medication_statement', {
        'status': 'active', 'medication_name': 'Example', 'dose': '1 tablet',
        'dose_times': ['08:00', '12:00'],
      }, day);
      final log = record('log-1', 'medication_dose_log', {
        'medication_record_id': 'med-1', 'event_type': 'taken',
        'occurred_at': DateTime(2026, 11, 2, 9).toIso8601String(),
      }, day);
      final result = MedicationAdherenceEngine.analyze([med, log], now: day, days: 1);
      expect(result.taken, 1);
      expect(result.doses.length, 2);
      expect(result.doses.where((d) => d.eventId == 'log-1').length, 1);
    });

    test('dose events are not reused across multiple scheduled occurrences', () {
      final med = record('med-2', 'medication_statement', {
        'status': 'active', 'medication_name': 'Example', 'dose_times': ['08:00', '20:00'],
      }, day);
      final logs = [
        record('log-a', 'medication_dose_log', {
          'medication_record_id': 'med-2', 'event_type': 'taken',
          'occurred_at': DateTime(2026, 11, 2, 8, 5).toIso8601String(),
        }, day),
        record('log-b', 'medication_dose_log', {
          'medication_record_id': 'med-2', 'event_type': 'missed',
          'occurred_at': DateTime(2026, 11, 2, 20, 5).toIso8601String(),
        }, day),
      ];
      final result = MedicationAdherenceEngine.analyze([med, ...logs], now: day, days: 1);
      expect(result.taken, 1);
      expect(result.missed, 1);
      expect(result.adherencePercent, 50);
    });
  });
}
