import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../data/patient_record_repository.dart';

class VoiceNotesPage extends StatefulWidget {
  const VoiceNotesPage({super.key});
  @override State<VoiceNotesPage> createState()=>_VoiceNotesPageState();
}
class _VoiceNotesPageState extends State<VoiceNotesPage> with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder=AudioRecorder();
  final AudioPlayer _player=AudioPlayer();
  final TextEditingController _title=TextEditingController();
  late final AnimationController _pulse=AnimationController(vsync:this,duration:const Duration(milliseconds:850))..repeat(reverse:true);
  bool _recording=false,_saving=false;
  String? _playingId;
  List<PatientRecord> _notes=[];
  @override void initState(){super.initState();_load();}
  @override void dispose(){_pulse.dispose();_recorder.dispose();_player.dispose();_title.dispose();super.dispose();}
  Future<void> _load() async {
    final all=await patientRecords.readAll();
    if(!mounted)return;
    setState(()=>_notes=all.where((r)=>r.resourceType=='document_reference'&&r.payload['document_type']=='other'&&r.payload['media_type']=='audio/m4a').toList());
  }
  Future<void> _toggle() async {
    if(_recording){
      final path=await _recorder.stop();if(path==null)return;
      setState(()=>_recording=false);setState(()=>_saving=true);
      try{
        final bytes=await File(path).readAsBytes();
        if(bytes.isEmpty)throw const FormatException('Recording was empty');
        final blob=await encryptedDocuments.save(Uint8List.fromList(bytes));
        final title=_title.text.trim().isEmpty?'Voice note · ${DateTime.now().toLocal().toString().substring(0,16)}':_title.text.trim();
        await patientRecords.create(resourceType:'document_reference',fields:{
          'document_type':'other','title':title,'media_type':'audio/m4a','encrypted_blob_id':blob,
          'document_date':DateTime.now().toUtc().toIso8601String(),'source':'patient_voice_note','storage':'encrypted_on_device',
        });
        await File(path).delete();_title.clear();await _load();
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Voice note encrypted and saved on this device.')));
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not save voice note: $e')));}
      finally{if(mounted)setState(()=>_saving=false);}
    }else{
      final permitted=await _recorder.hasPermission();
      if(!permitted){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Microphone permission is needed to record.')));return;}
      final dir=await getTemporaryDirectory();
      final path='${dir.path}/ujexa_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder:AudioEncoder.aacLc,bitRate:128000,sampleRate:44100),path:path);
      setState(()=>_recording=true);
    }
  }
  Future<void> _play(PatientRecord note) async {
    if(_playingId==note.id){await _player.stop();setState(()=>_playingId=null);return;}
    try{
      final bytes=await encryptedDocuments.read(note.payload['encrypted_blob_id'].toString());
      final dir=await getTemporaryDirectory();final file=File('${dir.path}/ujexa_playback_${note.id}.m4a');
      await file.writeAsBytes(bytes,flush:true);setState(()=>_playingId=note.id);
      await _player.play(DeviceFileSource(file.path));
      _player.onPlayerComplete.first.then((_){if(mounted)setState(()=>_playingId=null);file.delete().ignore();});
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This voice note could not be played.')));setState(()=>_playingId=null);}
  }
  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return ListView(padding:const EdgeInsets.fromLTRB(20,12,20,120),children:[
      const Text('Voice notes',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
      const SizedBox(height:6),Text('Capture details you would rather say than type. Audio is encrypted before it is saved.',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height:22),
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(28),gradient:LinearGradient(colors:dark?const[Color(0xFF30254A),Color(0xFF202B3C)]:const[Color(0xFFEEE5FF),Color(0xFFE2F3EE)])),child:Column(children:[
        Text(_recording?'Recording in progress':_saving?'Securing your note…':'Ready when you are',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
        const SizedBox(height:18),
        AnimatedBuilder(animation:_pulse,builder:(context,child)=>Transform.scale(scale:_recording?1+_pulse.value*.09:1,child:child),child:GestureDetector(onTap:_saving?null:_toggle,child:Container(width:92,height:92,decoration:BoxDecoration(shape:BoxShape.circle,color:_recording?const Color(0xFFD94E62):const Color(0xFF7950C8),boxShadow:[BoxShadow(color:const Color(0xFF7950C8).withOpacity(.25),blurRadius:24,spreadRadius:5)]),child:Icon(_recording?Icons.stop_rounded:Icons.mic_rounded,color:Colors.white,size:40)))),
        const SizedBox(height:14),Text(_recording?'Tap to stop and encrypt':'Tap the microphone to begin',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height:16),TextField(controller:_title,enabled:!_recording&&!_saving,decoration:const InputDecoration(prefixIcon:Icon(Icons.edit_note_rounded),labelText:'Give this note a title (optional)')),
      ])),
      const SizedBox(height:26),Text('SAVED NOTES · ${_notes.length}',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.2,color:Theme.of(context).colorScheme.primary)),
      const SizedBox(height:10),
      if(_notes.isEmpty)Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(children:[Icon(Icons.graphic_eq_rounded,size:38,color:Theme.of(context).colorScheme.primary),const SizedBox(height:8),const Text('Your voice library is empty',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:4),Text('Your saved recordings will appear here.',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))])))
      else ..._notes.map((note)=>Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:7),leading:const CircleAvatar(backgroundColor:Color(0xFFECE4FA),child:Icon(Icons.graphic_eq_rounded,color:Color(0xFF7950C8))),title:Text(note.payload['title']?.toString()??'Voice note',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(note.recordedAt.toLocal().toString().substring(0,16)),trailing:IconButton(onPressed:()=>_play(note),icon:Icon(_playingId==note.id?Icons.stop_circle_rounded:Icons.play_circle_fill_rounded,size:32,color:const Color(0xFF7950C8)))))),
    ]);
  }
}
