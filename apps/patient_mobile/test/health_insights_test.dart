
import 'package:flutter_test/flutter_test.dart';
import 'package:ujexa_health/domain/health_insights.dart';

void main() {
  group('HealthInsightsEngine', () {
    test('groups numeric observations by code and unit', () {
      final result = HealthInsightsEngine.analyze([
        {
          'resource_type': 'observation', 'code': 'heart_rate',
          'display': 'Heart rate', 'value_quantity': 72, 'unit': 'bpm',
          'effective_at': '2026-10-01T10:00:00Z', 'status': 'final',
        },
        {
          'resource_type': 'observation', 'code': 'heart_rate',
          'display': 'Heart rate', 'value_quantity': 80, 'unit': 'bpm',
          'effective_at': '2026-10-02T10:00:00Z', 'status': 'final',
        },
        {
          'resource_type': 'observation', 'code': 'heart_rate',
          'display': 'Heart rate', 'value_quantity': 1.2, 'unit': 'other',
          'effective_at': '2026-10-03T10:00:00Z', 'status': 'final',
        },
      ]);
      expect(result.vitalTrends, hasLength(2));
      final bpm = result.vitalTrends.firstWhere((t) => t.unit == 'bpm');
      expect(bpm.points, hasLength(2));
      expect(bpm.firstValue, 72);
      expect(bpm.latestValue, 80);
      expect(bpm.change, 8);
    });

    test('excludes cancelled and entered-in-error observations', () {
      final result = HealthInsightsEngine.analyze([
        {
          'resource_type': 'observation', 'code': 'weight',
          'display': 'Weight', 'value_quantity': 70, 'unit': 'kg',
          'effective_at': '2026-10-01T10:00:00Z', 'status': 'cancelled',
        },
      ]);
      expect(result.vitalTrends, isEmpty);
    });

    test('summarizes only explicitly active medications, allergies and conditions', () {
      final result = HealthInsightsEngine.analyze([
        {'resource_type': 'medication_statement', 'medication_name': 'A', 'status': 'active'},
        {'resource_type': 'medication_statement', 'medication_name': 'B', 'status': 'stopped'},
        {'resource_type': 'allergy', 'substance': 'Peanuts', 'status': 'active'},
        {'resource_type': 'allergy', 'substance': 'Pollen', 'status': 'inactive'},
        {'resource_type': 'condition', 'display': 'Example', 'status': 'active'},
        {'resource_type': 'condition', 'display': 'Resolved example', 'status': 'resolved'},
      ]);
      expect(result.activeMedications, hasLength(1));
      expect(result.otherMedicationCount, 1);
      expect(result.activeAllergies, hasLength(1));
      expect(result.activeConditions, hasLength(1));
    });

    test('extracts existing follow-up instructions without inventing reminders', () {
      final result = HealthInsightsEngine.analyze([
        {
          'resource_type': 'encounter',
          'started_at': '2026-10-02T10:00:00Z',
          'follow_up_instructions': 'Return for review in two weeks.',
        },
      ]);
      expect(result.followUpItems, hasLength(1));
      expect(result.followUpItems.single, contains('Return for review'));
    });

    test('does not include patient profile as a clinical record count', () {
      final result = HealthInsightsEngine.analyze([
        {'resource_type': 'patient_profile', 'preferred_name': 'Test'},
      ]);
      expect(result.totalRecords, 0);
      expect(result.vitalTrends, isEmpty);
    });
  });
}
