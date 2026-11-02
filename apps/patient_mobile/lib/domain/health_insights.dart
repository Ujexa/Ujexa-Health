
/// Descriptive, record-derived summaries. This module does not diagnose,
/// score risk, or compare values with clinical reference ranges.
class VitalPoint {
  const VitalPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class VitalTrend {
  const VitalTrend({
    required this.code,
    required this.label,
    required this.unit,
    required this.points,
  });
  final String code;
  final String label;
  final String unit;
  final List<VitalPoint> points;

  double get firstValue => points.first.value;
  double get latestValue => points.last.value;
  double get change => latestValue - firstValue;
  bool get hasMultiplePoints => points.length > 1;
}

class HealthInsightSnapshot {
  const HealthInsightSnapshot({
    required this.vitalTrends,
    required this.activeMedications,
    required this.otherMedicationCount,
    required this.activeAllergies,
    required this.activeConditions,
    required this.recentVisits,
    required this.followUpItems,
    required this.dataQualityNotes,
    required this.totalRecords,
  });

  final List<VitalTrend> vitalTrends;
  final List<Map<String, dynamic>> activeMedications;
  final int otherMedicationCount;
  final List<Map<String, dynamic>> activeAllergies;
  final List<Map<String, dynamic>> activeConditions;
  final List<Map<String, dynamic>> recentVisits;
  final List<String> followUpItems;
  final List<String> dataQualityNotes;
  final int totalRecords;
}

class HealthInsightsEngine {
  static HealthInsightSnapshot analyze(
    List<Map<String, dynamic>> records,
  ) {
    final valid = records.where((r) =>
      r['resource_type'] != 'patient_profile' &&
      r['resource_type'] != null
    ).toList();

    final observations = valid.where((r) =>
      r['resource_type'] == 'observation' &&
      r['status'] != 'cancelled' &&
      r['status'] != 'entered_in_error'
    ).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    final quality = <String>[];
    for (final r in observations) {
      final code = (r['code'] ?? '').toString().trim();
      final unit = (r['unit'] ?? '').toString().trim();
      final value = r['value_quantity'];
      final date = DateTime.tryParse((r['effective_at'] ?? '').toString());
      if (code.isEmpty || value is! num || !value.toDouble().isFinite || date == null) {
        quality.add('Some observations are missing a usable measurement, code or event date.');
        continue;
      }
      // Never combine different units under the same observation code.
      final key = '$code\u0000$unit';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final trends = <VitalTrend>[];
    for (final entry in grouped.entries) {
      final rows = entry.value
        ..sort((a, b) => DateTime.parse(a['effective_at'].toString())
          .compareTo(DateTime.parse(b['effective_at'].toString())));
      final first = rows.first;
      final code = first['code'].toString();
      final unit = (first['unit'] ?? '').toString();
      final points = rows.map((r) => VitalPoint(
        date: DateTime.parse(r['effective_at'].toString()),
        value: (r['value_quantity'] as num).toDouble(),
      )).toList();
      trends.add(VitalTrend(
        code: code,
        label: (first['display'] ?? code).toString(),
        unit: unit,
        points: List.unmodifiable(points),
      ));
    }
    trends.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    final meds = valid.where((r) => r['resource_type'] == 'medication_statement').toList();
    final activeMeds = meds.where((r) => r['status'] == 'active').toList()
      ..sort((a, b) => (a['medication_name'] ?? '').toString()
        .compareTo((b['medication_name'] ?? '').toString()));
    final otherMeds = meds.where((r) => r['status'] != 'active').length;

    final allergies = valid.where((r) =>
      r['resource_type'] == 'allergy' && r['status'] == 'active'
    ).toList();
    final conditions = valid.where((r) =>
      r['resource_type'] == 'condition' && r['status'] == 'active'
    ).toList();

    DateTime visitDate(Map<String, dynamic> row) =>
      DateTime.tryParse((row['started_at'] ?? '').toString()) ?? DateTime(1970);
    final visits = valid.where((r) => r['resource_type'] == 'encounter').toList()
      ..sort((a, b) => visitDate(b).compareTo(visitDate(a)));

    final followUps = <String>[];
    for (final visit in visits) {
      final instruction = (visit['follow_up_instructions'] ?? '').toString().trim();
      if (instruction.isNotEmpty) {
        final date = (visit['started_at'] ?? '').toString();
        followUps.add('${date.length >= 10 ? date.substring(0, 10) : 'Visit'}: $instruction');
      }
    }

    if (observations.isEmpty) {
      quality.add('No numeric vital observations are available yet, so trends cannot be calculated.');
    }
    if (meds.isEmpty) quality.add('No medication statements have been recorded.');
    if (visits.isEmpty) quality.add('No checkup or encounter history has been recorded.');

    return HealthInsightSnapshot(
      vitalTrends: List.unmodifiable(trends),
      activeMedications: List.unmodifiable(activeMeds),
      otherMedicationCount: otherMeds,
      activeAllergies: List.unmodifiable(allergies),
      activeConditions: List.unmodifiable(conditions),
      recentVisits: List.unmodifiable(visits.take(5)),
      followUpItems: List.unmodifiable(followUps),
      dataQualityNotes: List.unmodifiable(quality.toSet()),
      totalRecords: valid.length,
    );
  }

  static String describeChange(VitalTrend trend) {
    if (!trend.hasMultiplePoints) return 'One measurement recorded; no trend can be described.';
    final delta = trend.change;
    final sign = delta > 0 ? '+' : '';
    final value = delta.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return 'Recorded change: $sign$value ${trend.unit} across ${trend.points.length} measurements. This is a description of your records, not a clinical interpretation.';
  }
}
