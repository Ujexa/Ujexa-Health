
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum HealthNoticeKind { timed, regular, warning }

class HealthNotice {
  HealthNotice({required this.id, required this.title, required this.body,
    required this.kind, required this.createdAt, this.read = false,
    this.actionLabel, this.actionValue});
  final String id, title, body;
  final HealthNoticeKind kind;
  final DateTime createdAt;
  final bool read;
  final String? actionLabel, actionValue;
  Map<String, dynamic> toJson() => {'id':id,'title':title,'body':body,
    'kind':kind.name,'createdAt':createdAt.toIso8601String(),'read':read,
    'actionLabel':actionLabel,'actionValue':actionValue};
  factory HealthNotice.fromJson(Map<String,dynamic> j) => HealthNotice(
    id:j['id'], title:j['title'], body:j['body'],
    kind:HealthNoticeKind.values.firstWhere((e)=>e.name==j['kind'],orElse:()=>HealthNoticeKind.regular),
    createdAt:DateTime.parse(j['createdAt']), read:j['read']??false,
    actionLabel:j['actionLabel'], actionValue:j['actionValue']);
}

class HealthNotificationCenter {
  HealthNotificationCenter._();
  static final instance = HealthNotificationCenter._();
  final _plugin = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();
  static const _key = 'ujexa_health_notification_center_v1';
  final List<HealthNotice> _items = [];
  bool _ready = false;
  List<HealthNotice> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((e)=>!e.read).length;

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android,
      iOS: DarwinInitializationSettings(requestAlertPermission: true,
        requestBadgePermission: true, requestSoundPermission: true));
    await _plugin.initialize(settings);
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert:true,badge:true,sound:true);
    const channel = AndroidNotificationChannel('ujexa_health_important',
      'Ujexa Health reminders', description:'Patient-configured health reminders',
      importance: Importance.max, playSound:true, enableVibration:true);
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
    await _load();
    _ready = true;
  }

  Future<void> _load() async {
    final raw = await _storage.read(key:_key);
    if (raw == null) return;
    try { _items..clear()..addAll((jsonDecode(raw) as List).map((e)=>HealthNotice.fromJson(Map<String,dynamic>.from(e)))); }
    catch (_) { _items.clear(); }
  }
  Future<void> _save() => _storage.write(key:_key,value:jsonEncode(_items.map((e)=>e.toJson()).toList()));

  Future<void> add({required String title, required String body,
    required HealthNoticeKind kind, required DateTime when,
    String? actionLabel, String? actionValue, required int notificationId}) async {
    if (!_ready) await initialize();
    final now=DateTime.now();
    final notice=HealthNotice(id:'$notificationId-${now.microsecondsSinceEpoch}',
      title:title,body:body,kind:kind,createdAt:now,
      actionLabel:actionLabel,actionValue:actionValue);
    _items.insert(0,notice);
    if (_items.length>100) _items.removeRange(100,_items.length);
    await _save();
    final details=NotificationDetails(
      android:AndroidNotificationDetails('ujexa_health_important','Ujexa Health reminders',
        channelDescription:'Patient-configured health reminders',
        importance:Importance.max,priority:Priority.max,
        playSound:true,enableVibration:true,category:AndroidNotificationCategory.reminder),
      iOS:const DarwinNotificationDetails(presentAlert:true,presentSound:true,presentBadge:true));
    await _plugin.zonedSchedule(notificationId,title,body,
      tz.TZDateTime.from(when,tz.local),details,
      androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> addInternal({required String title, required String body,
    required HealthNoticeKind kind}) async {
    if (!_ready) await initialize();
    _items.insert(0,HealthNotice(id:'internal-${DateTime.now().microsecondsSinceEpoch}',
      title:title,body:body,kind:kind,createdAt:DateTime.now()));
    if (_items.length>100) _items.removeRange(100,_items.length);
    await _save();
  }

  Future<void> addInternalOnce({required String id, required String title,
    required String body, required HealthNoticeKind kind}) async {
    if (!_ready) await initialize();
    if (_items.any((item)=>item.id==id)) return;
    _items.insert(0,HealthNotice(id:id,title:title,body:body,kind:kind,createdAt:DateTime.now()));
    if (_items.length>100) _items.removeRange(100,_items.length);
    await _save();
  }

  Future<void> markRead(String id) async {
    final i=_items.indexWhere((e)=>e.id==id); if(i<0)return;
    final n=_items[i];
    _items[i]=HealthNotice(id:n.id,title:n.title,body:n.body,kind:n.kind,
      createdAt:n.createdAt,read:true,actionLabel:n.actionLabel,actionValue:n.actionValue);
    await _save();
  }
  Future<void> markAllRead() async {
    for(var i=0;i<_items.length;i++){final n=_items[i];_items[i]=HealthNotice(
      id:n.id,title:n.title,body:n.body,kind:n.kind,createdAt:n.createdAt,read:true,
      actionLabel:n.actionLabel,actionValue:n.actionValue);}
    await _save();
  }


  Future<void> scheduleMedication({
    required String medicationId,
    required String medicationName,
    required String prescribedDose,
    required List<String> times,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_ready) await initialize();
    final base=_stableId(medicationId);
    for(var i=0;i<1080;i++){await _plugin.cancel(base+i);}
    if(times.isEmpty)return;
    final now=DateTime.now();
    final firstDay=startDate!=null && startDate.isAfter(DateTime(now.year,now.month,now.day))
      ? DateTime(startDate.year,startDate.month,startDate.day) : DateTime(now.year,now.month,now.day);
    // Rolling 90-day local schedule. Refresh/rebuild when medication is edited or app opens.
    for(var day=0;day<90;day++){
      final date=firstDay.add(Duration(days:day));
      if(endDate!=null && date.isAfter(DateTime(endDate.year,endDate.month,endDate.day)))break;
      for(var slot=0;slot<times.length && slot<12;slot++){
        final parts=times[slot].split(':');
        if(parts.length!=2)continue;
        final hour=int.tryParse(parts[0]),minute=int.tryParse(parts[1]);
        if(hour==null||minute==null||hour<0||hour>23||minute<0||minute>59)continue;
        final scheduled=DateTime(date.year,date.month,date.day,hour,minute);
        if(!scheduled.isAfter(now))continue;
        final notificationId=base+day*12+slot;
        final details=NotificationDetails(
          android:AndroidNotificationDetails('ujexa_medication_doses','Medication dose reminders',
            channelDescription:'Reminders based on patient-entered medication schedules',
            importance:Importance.max,priority:Priority.max,playSound:true,enableVibration:true,
            category:AndroidNotificationCategory.reminder),
          iOS:const DarwinNotificationDetails(presentAlert:true,presentSound:true,presentBadge:true));
        await _plugin.zonedSchedule(notificationId,'Medication due: $medicationName',
          'Prescribed dose: $prescribedDose · Scheduled time ${times[slot]}',
          tz.TZDateTime.from(scheduled,tz.local),details,
          androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);
      }
    }
  }

  int _stableId(String value) {
    var hash=0x811c9dc5;
    for(final unit in value.codeUnits){hash=((hash^unit)*0x01000193)&0x7fffffff;}
    return 100000 + (hash % 100000000);
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
