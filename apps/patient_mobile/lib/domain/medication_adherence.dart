
import '../data/patient_record_repository.dart';

enum DoseState { taken, missed, skipped, overdue, upcoming }
class ScheduledDose {
  const ScheduledDose({required this.medicationId,required this.medicationName,
    required this.dose,required this.dueAt,required this.state,this.eventId});
  final String medicationId,medicationName,dose;
  final DateTime dueAt;
  final DoseState state;
  final String? eventId;
}
class MedicationAdherenceSnapshot {
  const MedicationAdherenceSnapshot({required this.doses,required this.taken,
    required this.missed,required this.skipped,required this.overdue,
    required this.upcoming,required this.adherencePercent});
  final List<ScheduledDose> doses;
  final int taken,missed,skipped,overdue,upcoming;
  final double? adherencePercent;
}
class MedicationAdherenceEngine {
  static MedicationAdherenceSnapshot analyze(List<PatientRecord> records,
      {DateTime? now, int days=30, Duration overdueAfter=const Duration(hours:2)}){
    final clock=now??DateTime.now();
    final meds=records.where((r)=>r.resourceType=='medication_statement'&&r.payload['status']=='active').toList();
    final logs=records.where((r)=>r.resourceType=='medication_dose_log').toList();
    final doses=<ScheduledDose>[];
    for(final med in meds){
      final p=med.payload;
      final times=(p['dose_times'] as List?)?.map((e)=>e.toString()).toList()??<String>[];
      if(times.isEmpty)continue;
      final start=DateTime.tryParse((p['start_date']??'').toString());
      final end=DateTime.tryParse((p['end_date']??'').toString());
      // A dose event may satisfy at most one scheduled occurrence. Matching
      // is constrained to this medication and a six-hour window; nearest wins.
      final usedLogIds=<String>{};
      final linked=logs.where((l)=>l.payload['medication_record_id']==med.id).toList();
      for(var offset=days-1;offset>=0;offset--){
        final date=DateTime(clock.year,clock.month,clock.day).subtract(Duration(days:offset));
        if(start!=null&&date.isBefore(DateTime(start.year,start.month,start.day)))continue;
        if(end!=null&&date.isAfter(DateTime(end.year,end.month,end.day)))continue;
        for(final raw in times){
          final parts=raw.split(':');
          if(parts.length!=2)continue;
          final h=int.tryParse(parts[0]),m=int.tryParse(parts[1]);
          if(h==null||m==null||h<0||h>23||m<0||m>59)continue;
          final due=DateTime(date.year,date.month,date.day,h,m);
          PatientRecord? match;
          var best=const Duration(days:999);
          var tied=false;
          final tiedLogIds=<String>{};
          for(final log in linked){
            if(usedLogIds.contains(log.id)) continue;
            final at=DateTime.tryParse((log.payload['occurred_at']??'').toString())??log.recordedAt.toLocal();
            final delta=at.difference(due).abs();
            if(delta<=const Duration(hours:6)){
              if(delta<best){best=delta;match=log;tied=false;tiedLogIds
                ..clear()..add(log.id);}
              else if(delta==best){tied=true;tiedLogIds.add(log.id);}
            }
          }
          // Do not arbitrarily attribute an equally-close event to one of two
          // doses. Leave both unresolved for patient review.
          if(tied) { match=null; usedLogIds.addAll(tiedLogIds); }
          if(match!=null){
            usedLogIds.add(match.id);
            final event=(match.payload['event_type']??'unknown').toString();
            final state=switch(event){'taken'=>DoseState.taken,'missed'=>DoseState.missed,'skipped'=>DoseState.skipped,_=>DoseState.overdue};
            doses.add(ScheduledDose(medicationId:med.id,medicationName:(p['medication_name']??'Medication').toString(),
              dose:(p['dose']??'').toString(),dueAt:due,state:state,eventId:match.id));
          }else{
            final state=due.isAfter(clock)?DoseState.upcoming:
              (clock.difference(due)>=overdueAfter?DoseState.overdue:DoseState.upcoming);
            doses.add(ScheduledDose(medicationId:med.id,medicationName:(p['medication_name']??'Medication').toString(),
              dose:(p['dose']??'').toString(),dueAt:due,state:state));
          }
        }
      }
    }
    doses.sort((a,b)=>b.dueAt.compareTo(a.dueAt));
    final taken=doses.where((d)=>d.state==DoseState.taken).length;
    final missed=doses.where((d)=>d.state==DoseState.missed).length;
    final skipped=doses.where((d)=>d.state==DoseState.skipped).length;
    final overdue=doses.where((d)=>d.state==DoseState.overdue).length;
    final upcoming=doses.where((d)=>d.state==DoseState.upcoming).length;
    final resolved=taken+missed+skipped;
    return MedicationAdherenceSnapshot(doses:doses,taken:taken,missed:missed,
      skipped:skipped,overdue:overdue,upcoming:upcoming,
      adherencePercent:resolved==0?null:taken/resolved*100);
  }
}
