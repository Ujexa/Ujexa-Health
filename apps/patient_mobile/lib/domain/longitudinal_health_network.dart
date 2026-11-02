
import 'dart:math';
import '../data/patient_record_repository.dart';

/// A private, per-patient self-supervised model.
///
/// This is a personal-pattern monitor, not a diagnostic model. It learns to
/// reconstruct the patient's own historical daily measurement vectors and
/// reports reconstruction deviation only when the history is sufficiently
/// populated. It never emits disease labels, risk probabilities or treatment.
class LongitudinalHealthNetwork {
  static const features = <String>[
    'heart_rate','systolic_bp','diastolic_bp','blood_glucose','body_temperature',
    'oxygen_saturation','body_weight','respiratory_rate','medication_adherence','encounter_count',
  ];
  static const minHistoryDays = 20;
  static const inputSize = 60; // Three daily frames × (10 normalized values + 10 presence masks)
  final _rng = Random(73129);
  late final _DenseLayer _enc1 = _DenseLayer(inputSize,40,_rng);
  late final _DenseLayer _enc2 = _DenseLayer(40,16,_rng);
  late final _DenseLayer _dec1 = _DenseLayer(16,40,_rng);
  late final _DenseLayer _dec2 = _DenseLayer(40,inputSize,_rng);

  HealthNetworkResult analyze(List<PatientRecord> records) {
    final daily = _dailyVectors(records);
    if (daily.length < minHistoryDays) {
      return HealthNetworkResult.insufficient(daily.length, minHistoryDays);
    }
    final chronological = daily.keys.toList()..sort();
    final raw = chronological.map((d)=>daily[d]!).toList();
    final medians=<double>[], scales=<double>[];
    for(var f=0;f<10;f++){
      final vals=raw.map((v)=>v[f]).whereType<double>().toList()..sort();
      final med=_median(vals);
      final deviations=vals.map((v)=>(v-med).abs()).toList()..sort();
      medians.add(med);
      scales.add(max(_median(deviations)*1.4826, _fallbackScale(f,med)).toDouble());
    }
    final dailyFrames=<List<double>>[];
    for(final row in raw){
      final frame=<double>[];
      for(var f=0;f<10;f++){
        final value=row[f];
        frame.add(value==null?0.0:((value-medians[f])/scales[f]).clamp(-5.0,5.0).toDouble());
      }
      for(var f=0;f<10;f++){frame.add(row[f]==null?0.0:1.0);}
      dailyFrames.add(frame);
    }
    // Three-day temporal windows let the network model short-term direction
    // and persistence rather than treating each observation day independently.
    final vectors=<List<double>>[];
    for(var day=0;day<dailyFrames.length;day++){
      final window=<double>[];
      for(var back=2;back>=0;back--){
        final index=day-back;
        window.addAll(index<0?List<double>.filled(20,0):dailyFrames[index]);
      }
      vectors.add(window);
    }
    // Train only on the earlier portion; reserve the most recent observations
    // for a chronological holdout to reduce optimistic self-evaluation.
    final split=max(12,(vectors.length*0.8).floor()).clamp(1,vectors.length-1).toInt();
    final training=vectors.take(split).toList();
    for(var epoch=0;epoch<90;epoch++){
      for(final sample in training){
        _train(sample, learningRate:0.0015);
      }
    }
    final recent=vectors.skip(split).toList();
    final errors=recent.map(_reconstructionError).toList();
    final baselineErrors=training.map(_reconstructionError).toList();
    final baseline=_median(baselineErrors);
    final spread=max(_median(baselineErrors.map((e)=>(e-baseline).abs()).toList())*1.4826,0.015);
    final latestError=errors.isEmpty?0.0:errors.last;
    final deviation=((latestError-baseline)/spread).clamp(0.0,99.0).toDouble();
    final changed=deviation>=3.5;
    final available=raw.last.where((v)=>v!=null).length;
    return HealthNetworkResult(
      ready:true, historyDays:daily.length, trainingDays:training.length,
      evaluatedDays:recent.length, reconstructionDeviation:deviation,
      personalPatternChanged:changed,
      summary: changed
        ? 'Recent recorded measurements differ from the patterns learned from earlier entries. Review the underlying measurements and context.'
        : 'Recent measurements are broadly consistent with the modelled personal history.',
      limitations: available<3
        ? 'The latest day has limited measurement coverage; the comparison may be incomplete.'
        : 'This is a self-supervised personal-pattern comparison, not a clinical assessment.',
    );
  }


  Map<DateTime,List<double?>> _dailyVectors(List<PatientRecord> records) {
    final buckets=<DateTime,Map<int,List<double>>>{};
    DateTime? localDate(dynamic raw){
      final d=DateTime.tryParse((raw??'').toString())?.toLocal();
      return d==null?null:DateTime(d.year,d.month,d.day);
    }
    void add(DateTime date,int index,double value){
      if(!value.isFinite)return;
      buckets.putIfAbsent(date,()=>{});
      buckets[date]!.putIfAbsent(index,()=>[]).add(value);
    }
    for(final r in records){
      final p=r.payload;
      if(r.resourceType=='observation'){
        final date=localDate(p['effective_at']); if(date==null)continue;
        final code=(p['code']??'').toString(), value=p['value_quantity'];
        if(code=='heart_rate'&&value is num)add(date,0,value.toDouble());
        if(code=='blood_glucose'&&value is num)add(date,3,value.toDouble());
        if(code=='body_temperature'&&value is num)add(date,4,value.toDouble());
        if(code=='oxygen_saturation'&&value is num)add(date,5,value.toDouble());
        if(code=='body_weight'&&value is num)add(date,6,value.toDouble());
        if(code=='respiratory_rate'&&value is num)add(date,7,value.toDouble());
        if(code=='blood_pressure'&&p['components'] is Map){
          final c=Map<String,dynamic>.from(p['components'] as Map);
          if(c['systolic'] is num)add(date,1,(c['systolic'] as num).toDouble());
          if(c['diastolic'] is num)add(date,2,(c['diastolic'] as num).toDouble());
        }
      } else if(r.resourceType=='medication_dose_log'){
        final date=localDate(p['occurred_at'])??localDate(r.recordedAt.toIso8601String());
        if(date==null)continue;
        final event=p['event_type'];
        if(event=='taken')add(date,8,1);
        if(event=='missed'||event=='skipped')add(date,8,0);
      } else if(r.resourceType=='encounter'){
        final date=localDate(p['started_at']); if(date!=null)add(date,9,1);
      }
    }
    final result=<DateTime,List<double?>>{};
    for(final entry in buckets.entries){
      result[entry.key]=List.generate(10,(index){
        final vals=entry.value[index];
        if(vals==null||vals.isEmpty)return null;
        return vals.reduce((a,b)=>a+b)/vals.length;
      });
    }
    return result;
  }

  double _fallbackScale(int index,double median)=>switch(index){
    0=>max(median.abs()*0.08,2.0).toDouble(),
    1||2=>max(median.abs()*0.08,3.0).toDouble(),
    3=>max(median.abs()*0.10,0.5).toDouble(),
    4=>max(median.abs()*0.03,0.2).toDouble(),
    5=>max(median.abs()*0.03,1.0).toDouble(),
    6=>max(median.abs()*0.08,1.0).toDouble(),
    7=>max(median.abs()*0.10,1.0).toDouble(),
    8=>1.0,
    _=>1.0,
  };
  double _median(List<double> v){
    if(v.isEmpty)return 0;
    final a=[...v]..sort();
    return a.length.isOdd?a[a.length~/2]:(a[a.length~/2-1]+a[a.length~/2])/2;
  }
  void _train(List<double> x,{required double learningRate}){
    final a=_enc1.forward(x),b=_enc2.forward(a),c=_dec1.forward(b),y=_dec2.forward(c);
    final dy=List.generate(inputSize,(i)=>2*(y[i]-x[i])/inputSize);
    final dc=_dec2.backward(dy,learningRate);
    final db=_dec1.backward(dc,learningRate);
    final da=_enc2.backward(db,learningRate);
    _enc1.backward(da,learningRate);
  }
  double _reconstructionError(List<double> x){
    final y=_dec2.forward(_dec1.forward(_enc2.forward(_enc1.forward(x))));
    var sum=0.0;
    for(var i=0;i<inputSize;i++){final d=x[i]-y[i];sum+=d*d;}
    return sum/inputSize;
  }
}

class _DenseLayer {
  _DenseLayer(this.inputs,this.outputs,Random rng)
    : weights=List.generate(outputs,(_)=>List.generate(inputs,(_)=>(rng.nextDouble()*2-1)*sqrt(2/inputs))),
      biases=List.filled(outputs,0);
  final int inputs,outputs;
  final List<List<double>> weights;
  final List<double> biases;
  List<double> _lastInput=[];
  List<double> _lastOutput=[];
  List<double> forward(List<double> x){
    _lastInput=x;
    _lastOutput=List.generate(outputs,(o){
      var z=biases[o];
      for(var i=0;i<inputs;i++){z+=weights[o][i]*x[i];}
      final bounded = z.clamp(-10.0, 10.0).toDouble();
      final e = exp(2 * bounded);
      return (e - 1) / (e + 1);
    });
    return _lastOutput;
  }
  List<double> backward(List<double> gradOutput,double lr){
    final gradInput=List.filled(inputs,0.0);
    for(var o=0;o<outputs;o++){
      final gz=gradOutput[o]*(1-_lastOutput[o]*_lastOutput[o]);
      for(var i=0;i<inputs;i++){
        gradInput[i]+=weights[o][i]*gz;
        weights[o][i]-=lr*gz*_lastInput[i];
      }
      biases[o]-=lr*gz;
    }
    return gradInput;
  }
}

class HealthNetworkResult {
  const HealthNetworkResult({required this.ready,required this.historyDays,
    required this.trainingDays,required this.evaluatedDays,
    required this.reconstructionDeviation,required this.personalPatternChanged,
    required this.summary,required this.limitations});
  const HealthNetworkResult.insufficient(int days,int minimum)
    :ready=false,historyDays=days,trainingDays=0,evaluatedDays=0,
     reconstructionDeviation=0,personalPatternChanged=false,
     summary='Building your personal baseline: more dated measurements are needed.',
     limitations='At least $minimum distinct days with supported measurements are required before this model runs.';
  final bool ready,personalPatternChanged;
  final int historyDays,trainingDays,evaluatedDays;
  final double reconstructionDeviation;
  final String summary,limitations;
}
