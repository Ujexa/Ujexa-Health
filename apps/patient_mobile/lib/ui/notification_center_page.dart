
import 'package:flutter/material.dart';
import '../data/notification_center.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});
  @override State<NotificationCenterPage> createState()=>_NotificationCenterPageState();
}
class _NotificationCenterPageState extends State<NotificationCenterPage> {
  static const purple=Color(0xFF7938DB);
  Color get ink => Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF171B3D);
  final center=HealthNotificationCenter.instance;
  @override void initState(){super.initState();center.initialize().then((_) {if(mounted)setState((){});});}
  Color _tone(HealthNoticeKind k)=>switch(k){HealthNoticeKind.timed=>const Color(0xFF3977D5),HealthNoticeKind.regular=>const Color(0xFF27866D),HealthNoticeKind.warning=>const Color(0xFFD45A47)};
  IconData _icon(HealthNoticeKind k)=>switch(k){HealthNoticeKind.timed=>Icons.alarm_rounded,HealthNoticeKind.regular=>Icons.notifications_active_outlined,HealthNoticeKind.warning=>Icons.warning_amber_rounded};
  Future<void> _create() async {
    final title=TextEditingController(), body=TextEditingController();
    var kind=HealthNoticeKind.timed;
    var when=DateTime.now().add(const Duration(minutes:5));
    final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,
      backgroundColor:Colors.transparent,builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Container(
        padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(ctx).viewInsets.bottom+24),
        decoration:BoxDecoration(color:Theme.of(ctx).colorScheme.surfaceContainerLow,borderRadius:const BorderRadius.vertical(top:Radius.circular(28))),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Create a useful reminder',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:ink)),
          const SizedBox(height:14),
          TextField(controller:title,decoration:const InputDecoration(labelText:'What needs attention?',border:OutlineInputBorder())),
          const SizedBox(height:10),
          TextField(controller:body,maxLines:2,decoration:const InputDecoration(labelText:'Helpful detail',border:OutlineInputBorder())),
          const SizedBox(height:12),
          SegmentedButton<HealthNoticeKind>(segments:const [
            ButtonSegment(value:HealthNoticeKind.timed,label:Text('Timed'),icon:Icon(Icons.alarm)),
            ButtonSegment(value:HealthNoticeKind.regular,label:Text('Regular'),icon:Icon(Icons.notifications)),
            ButtonSegment(value:HealthNoticeKind.warning,label:Text('Warning'),icon:Icon(Icons.warning_amber)),
          ],selected:{kind},onSelectionChanged:(v)=>setSheet(()=>kind=v.first)),
          const SizedBox(height:10),
          OutlinedButton.icon(onPressed:()async{
            final d=await showDatePicker(context:ctx,initialDate:when.isBefore(DateTime.now())?DateTime.now():when,
              firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));
            if(d==null)return;
            final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(when));
            if(t!=null)setSheet(()=>when=DateTime(d.year,d.month,d.day,t.hour,t.minute));
          },icon:const Icon(Icons.calendar_month),label:Text('Schedule: ${when.toLocal()}')),
          const SizedBox(height:14),
          SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save reminder')))
        ]))));
    if(ok!=true)return;
    if(title.text.trim().isEmpty||body.text.trim().isEmpty||!when.isAfter(DateTime.now())){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add a title, detail and a future time.')));
      return;
    }
    final id=DateTime.now().millisecondsSinceEpoch.remainder(2000000000);
    await center.add(title:title.text.trim(),body:body.text.trim(),kind:kind,when:when,notificationId:id);
    if(mounted)setState((){});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Theme.of(context).scaffoldBackgroundColor,
    appBar:AppBar(title:Text('Notification centre',style:TextStyle(fontWeight:FontWeight.w800,color:ink)),
      actions:[TextButton(onPressed:()async{await center.markAllRead();setState((){});},child:const Text('Mark all read'))]),
    floatingActionButton:FloatingActionButton.extended(onPressed:_create,backgroundColor:purple,
      foregroundColor:Colors.white,icon:const Icon(Icons.add_alarm),label:const Text('New reminder')),
    body:RefreshIndicator(onRefresh:()async{await center.initialize();setState((){});},
      child:ListView(padding:const EdgeInsets.fromLTRB(18,10,18,100),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF30205E),Color(0xFF7945C8)])),
          child:Row(children:[const Icon(Icons.notifications_active_rounded,color:Colors.white,size:38),
            const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Your attention, protected.',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),
              Text('${center.unreadCount} unread · ${center.items.length} saved notices',style:const TextStyle(color:Color(0xFFE4D8FF))) ]))])),
        const SizedBox(height:20),
        const Text('YOUR INBOX',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.2,fontSize:11)),
        const SizedBox(height:8),
        if(center.items.isEmpty) Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerLow,borderRadius:BorderRadius.circular(20)),
          child:Column(children:[const Icon(Icons.notifications_off_outlined,size:38,color:Color(0xFF9A91B3)),
            SizedBox(height:8),Text('All quiet here',style:TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:17)),
            Text('Only reminders you create or important app events will appear here.',textAlign:TextAlign.center,style:TextStyle()) ]))
        else ...center.items.map((n)=>Padding(padding:const EdgeInsets.only(bottom:9),child:InkWell(
          borderRadius:BorderRadius.circular(18),onTap:()async{await center.markRead(n.id);setState((){});},
          child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerLow,borderRadius:BorderRadius.circular(18),
            border:Border.all(color:n.read?const Color(0xFFEDECF4):_tone(n.kind).withOpacity(.35))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(width:42,height:42,decoration:BoxDecoration(color:_tone(n.kind).withOpacity(.11),borderRadius:BorderRadius.circular(14)),
                child:Icon(_icon(n.kind),color:_tone(n.kind))),
              const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Expanded(child:Text(n.title,style:TextStyle(fontWeight:FontWeight.w800,color:ink))),
                  if(!n.read)Container(width:7,height:7,decoration:BoxDecoration(color:_tone(n.kind),shape:BoxShape.circle))]),
                const SizedBox(height:4),Text(n.body,style:const TextStyle(height:1.3)),
                const SizedBox(height:6),Text('${n.kind.name.toUpperCase()}  ·  ${n.createdAt.toLocal().toString().substring(0,16)}',
                  style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:_tone(n.kind)))
              ]))
            ])) ))),
        const SizedBox(height:8),
        Text('Sound and delivery',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:ink)),
        const SizedBox(height:5),
        const Text('Scheduled alerts use the device notification sound and vibration. Delivery depends on OS permission, battery policy and device settings.',
          style:TextStyle(height:1.35,fontSize:12))
      ])));
}
