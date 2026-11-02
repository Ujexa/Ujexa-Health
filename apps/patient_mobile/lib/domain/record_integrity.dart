import '../data/patient_record_repository.dart';

class RecordIntegrityFinding {
  const RecordIntegrityFinding({required this.kind,required this.title,required this.detail,required this.recordIds});
  final String kind,title,detail;
  final List<String> recordIds;
}
class RecordIntegrityReport {
  const RecordIntegrityReport(this.findings,{required this.recordsReviewed});
  final List<RecordIntegrityFinding> findings;
  final int recordsReviewed;
}
class RecordIntegrity {
  static RecordIntegrityReport analyze(List<PatientRecord> records){
    final findings=<RecordIntegrityFinding>[];
    final seen=<String,List<PatientRecord>>{};
    for(final r in records){
      final keys=switch(r.resourceType){
        'observation'=>['observation',r.payload['code'],r.payload['effective_at'],r.payload['value_quantity'],r.payload['unit']],
        'medication_statement'=>['medication',r.payload['medication_name']?.toString().toLowerCase(),r.payload['strength']?.toString().toLowerCase(),r.payload['start_date']],
        'condition'=>['condition',r.payload['display']?.toString().toLowerCase(),r.payload['onset_date']],
        'allergy'=>['allergy',r.payload['substance']?.toString().toLowerCase()],
        _=>[],
      };
      if(keys.isEmpty)continue;
      final key=keys.join('|');
      seen.putIfAbsent(key,()=>[]).add(r);
    }
    for(final group in seen.values.where((g)=>g.length>1)){
      findings.add(RecordIntegrityFinding(kind:'possible_duplicate',title:'Possible duplicate records',
        detail:'${group.length} records have matching key fields. Review before deleting or merging; matching does not prove duplication.',
        recordIds:group.map((r)=>r.id).toList()));
    }
    final observations=records.where((r)=>r.resourceType=='observation').toList();
    for(final group in _groupBy(observations,(r)=>'${r.payload['code']}|${r.payload['effective_at']}|${r.payload['unit']}').values){
      final values=group.map((r)=>r.payload['value_quantity']).whereType<num>().toSet();
      if(values.length>1){
        findings.add(RecordIntegrityFinding(kind:'conflicting_measurements',title:'Conflicting measurements',
          detail:'Multiple different values exist for the same measurement code, time and unit. Check source documents and entry details.',
          recordIds:group.map((r)=>r.id).toList()));
      }
    }
    return RecordIntegrityReport(List.unmodifiable(findings),recordsReviewed:records.length);
  }
  static Map<K,List<T>> _groupBy<T,K>(Iterable<T> rows,K Function(T) key){
    final out=<K,List<T>>{};for(final row in rows){out.putIfAbsent(key(row),()=>[]).add(row);}return out;
  }
}
