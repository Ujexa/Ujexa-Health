import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'data/encrypted_record_store.dart';
import 'data/local_vault_key_provider.dart';
import 'data/patient_record_repository.dart';
import 'data/encrypted_document_store.dart';
import 'data/document_text_extractor.dart';
import 'domain/health_insights.dart';
import 'domain/longitudinal_health_network.dart';
import 'domain/medication_adherence.dart';
import 'domain/symptom_journal_intelligence.dart';
import 'domain/cross_domain_health_intelligence.dart';
import 'domain/document_understanding.dart';
import 'domain/record_integrity.dart';
import 'data/notification_center.dart';
import 'ui/notification_center_page.dart';

late final PatientRecordRepository patientRecords;
late final EncryptedDocumentStore encryptedDocuments;
late final DocumentTextExtractor documentTextExtractor;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dekProvider = SecureStorageVaultDekProvider();
  final store = SqlCipherHealthRecordStore(
    codec: AesGcmHealthRecordCodec(dekProvider, vaultId: 'local-patient-vault'),
  );
  await store.open();
  patientRecords = PatientRecordRepository(store);
  encryptedDocuments = EncryptedDocumentStore(store.codec);
  documentTextExtractor = DocumentTextExtractor();
  await HealthNotificationCenter.instance.initialize();
  runApp(const UjexaHealthApp());
}

class UjexaHealthApp extends StatelessWidget {
  const UjexaHealthApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ujexa Health',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8F8FD),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7938DB)),
      fontFamily: 'Roboto',
    ),
    home: const UjexaStartupGate(),
  );
}


class UjexaStartupGate extends StatefulWidget {
  const UjexaStartupGate({super.key});
  @override State<UjexaStartupGate> createState()=>_UjexaStartupGateState();
}
class _UjexaStartupGateState extends State<UjexaStartupGate> with SingleTickerProviderStateMixin {
  late final AnimationController _controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1500))..forward();
  @override void initState(){super.initState();Future.delayed(const Duration(milliseconds:1900),(){
    if(mounted)Navigator.of(context).pushReplacement(PageRouteBuilder(pageBuilder:(_,__,___)=>const PatientShell(),
      transitionDuration:const Duration(milliseconds:450),transitionsBuilder:(_,a,__,child)=>FadeTransition(opacity:a,child:child)));
  });}
  @override void dispose(){_controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFF171333),
    body:Center(child:AnimatedBuilder(animation:_controller,builder:(context,child){
      final t=_controller.value;
      return Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        SizedBox(width:150,height:150,child:Stack(alignment:Alignment.center,children:[
          Transform.scale(scale:.75+t*.45,child:Container(width:130,height:130,decoration:BoxDecoration(
            shape:BoxShape.circle,border:Border.all(color:const Color(0xFFB99BFF).withOpacity(1-t*.65),width:2)))),
          Transform.rotate(angle:t*1.4,child:Container(width:104,height:104,decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(32),gradient:const LinearGradient(colors:[Color(0xFFB18AFF),Color(0xFF6C42C9)]),
            boxShadow:[BoxShadow(color:const Color(0xFF9C6BFF).withOpacity(.25+t*.2),blurRadius:30)]),
            child:const Icon(Icons.favorite_rounded,color:Colors.white,size:52))),
          Positioned(top:8,right:14,child:Container(width:10,height:10,decoration:const BoxDecoration(color:Color(0xFF74E2C1),shape:BoxShape.circle)))
        ])),
        const SizedBox(height:26),const Text('UJEXA HEALTH',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900,letterSpacing:3)),
        const SizedBox(height:7),const Text('Your health. Your records. Your control.',style:TextStyle(color:Color(0xFFC8BDE6),fontSize:12)),
        const SizedBox(height:28),SizedBox(width:110,child:LinearProgressIndicator(value:t,minHeight:3,
          backgroundColor:Colors.white12,color:const Color(0xFFB99BFF),borderRadius:BorderRadius.circular(10)))
      ]);
    })));
}

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int tab = 0;
  static const ink = Color(0xFF171B3D);
  static const purple = Color(0xFF7938DB);

  void openAdd() => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => AddRecordSheet(onSelect: (label) {
      Navigator.pop(context);
      if (label == 'Log checkup') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckupForm()));
      } else if (label == 'Medication log') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationManagementPage()));
      } else if (['Vitals', 'Medication', 'Allergies', 'Conditions'].contains(label)) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClinicalRecordForm(kind: label)));
      } else if (label == 'Manage sharing consent') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SharingConsentPage()));
      } else if (label == 'Record history') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordHistoryPage()));
      } else if (label == 'Record integrity') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordIntegrityPage()));
      } else if (label == 'Emergency summary') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencySummaryPage()));
      } else if (['Appointment','Lifestyle entry','Preventive care','Share health records'].contains(label)) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StageCaptureForm(kind: label)));
      } else if (label == 'Review document extractions') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentPromotionWorkspace()));
      } else if (label == 'Medical document') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentCaptureForm()));
      } else if (label == 'Symptoms') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SymptomEntryForm()));
      } else if (label == 'Journal') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthJournalForm()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label will be available in a later capture module.')),
        );
      }
    }),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onAdd: openAdd),
      RecordsPage(onAdd: openAdd),
      const HealthInsightsPage(),
      const PatientProfilePage(),
      const NotificationCenterPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_open_outlined), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications_active), label: 'Alerts'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAdd, backgroundColor: purple, foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}



class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.onAdd});
  final VoidCallback onAdd;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  static const ink = Color(0xFF171B3D);
  static const muted = Color(0xFF69708E);
  late Future<List<PatientRecord>> _future;
  final _search = TextEditingController();
  String _category = 'all';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _future = patientRecords.readAll();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    setState(() => _future = patientRecords.readAll());
    await _future;
  }

  String _categoryFor(String type) => switch (type) {
    'encounter' => 'visits',
    'observation' => 'vitals',
    'medication_statement' || 'medication_dose_log' => 'medications',
    'allergy' => 'allergies',
    'condition' => 'conditions',
    'document_reference' => 'documents',
    'symptom_entry' => 'symptoms',
    'health_journal' => 'journal',
    _ => 'other',
  };

  String _title(PatientRecord record) => switch (record.resourceType) {
    'encounter' => 'Checkup / visit',
    'observation' => 'Vital observation',
    'medication_statement' => 'Medication',
    'medication_dose_log' => 'Medication dose event',
    'allergy' => 'Allergy',
    'condition' => 'Condition',
    'document_reference' => 'Medical document',
    'symptom_entry' => 'Symptom episode',
    'health_journal' => 'Health journal',
    _ => 'Health record',
  };

  String _summary(PatientRecord record) {
    final p = record.payload;
    final keys = switch (record.resourceType) {
      'encounter' => ['reason', 'provider_name', 'organization', 'clinical_notes'],
      'observation' => ['display', 'value_quantity', 'value_text', 'unit', 'notes'],
      'medication_statement' => ['medication_name', 'dose', 'frequency', 'status', 'notes'],
      'medication_dose_log' => ['event_type', 'occurred_at', 'medication_record_id', 'notes'],
      'allergy' => ['substance', 'reaction', 'severity', 'status'],
      'condition' => ['display', 'status', 'notes'],
      'document_reference' => ['title', 'document_type', 'issuing_organization', 'extraction_status', 'extracted_text'],
      'symptom_entry' => ['symptom_name','severity','body_area','duration','possible_triggers','notes'],
      'health_journal' => ['entry_text','mood_score','energy_score','stress_score'],
      _ => ['title', 'display', 'reason'],
    };
    final parts = <String>[];
    for (final key in keys) {
      final value = p[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        final label = key.replaceAll('_', ' ');
        parts.add('$label: $value');
      }
    }
    return parts.isEmpty ? 'No additional details' : parts.join(' · ');
  }

  DateTime _eventDate(PatientRecord record) {
    final p = record.payload;
    final raw = switch (record.resourceType) {
      'encounter' => p['started_at'],
      'observation' => p['effective_at'],
      'document_reference' => p['document_date'],
      _ => null,
    };
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return record.recordedAt;
  }

  String _dateLabel(DateTime value) {
    final d = value.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _matches(PatientRecord r) {
    if (r.resourceType == 'patient_profile') return false;
    if (_category != 'all' && _categoryFor(r.resourceType) != _category) return false;
    if (_range != null) {
      final date = _eventDate(r).toLocal();
      final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
      if (date.isBefore(start) || date.isAfter(end)) return false;
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${_title(r)} ${_summary(r)} ${r.resourceType}'.toLowerCase().contains(q);
  }

  Future<void> _showDetails(PatientRecord record, List<PatientRecord> all) async {
    final relatedIds = (record.payload['related_observation_ids'] is List)
      ? (record.payload['related_observation_ids'] as List).whereType<String>().toSet()
      : <String>{};
    final related = all.where((r) => relatedIds.contains(r.id)).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          maxChildSize: .94,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
            children: [
              Text(_title(record), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 5),
              Text('${_dateLabel(_eventDate(record))} · Version ${record.version}', style: const TextStyle(color: muted)),
              const SizedBox(height: 12),
              const Text('PATIENT-ENTERED · UNVERIFIED', style: TextStyle(fontSize: 10, letterSpacing: .7, fontWeight: FontWeight.w800, color: Color(0xFF8A6C24))),
              const SizedBox(height: 16),
              ...record.payload.entries
                .where((e) => !{'resource_type', 'resource_id', 'version', 'provenance', 'encrypted_blob_id'}.contains(e.key) && e.value != null)
                .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: .5, color: muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(e.value.toString(), style: const TextStyle(fontSize: 15, color: ink)),
                  ]),
                )),
              if (related.isNotEmpty) ...[
                const Divider(),
                const Text('Related records', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 8),
                ...related.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text(_title(r)),
                  subtitle: Text(_summary(r), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _showDetails(r, all),
                )),
              ],
              const SizedBox(height: 12),
              const Text('This information has not been independently verified by a clinician.', style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PatientRecord>>(
    future: _future,
    builder: (context, snapshot) {
      final all = snapshot.data ?? const <PatientRecord>[];
      final records = all.where(_matches).toList()
        ..sort((a, b) => _eventDate(b).compareTo(_eventDate(a)));
      final grouped = <String, List<PatientRecord>>{};
      for (final record in records) {
        grouped.putIfAbsent(_dateLabel(_eventDate(record)), () => []).add(record);
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
          children: [
            const Text('Your health timeline', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 6),
            const Text('A chronological view of your health records, decrypted locally on this device.', style: TextStyle(color: muted)),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: widget.onAdd, icon: const Icon(Icons.add), label: const Text('Add to health record')),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search your records',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => _search.clear()),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final item in const [
                  ('all', 'All'), ('visits', 'Visits'), ('vitals', 'Vitals'),
                  ('medications', 'Medications'), ('allergies', 'Allergies'),
                  ('conditions', 'Conditions'), ('documents', 'Documents'), ('symptoms', 'Symptoms'), ('journal', 'Journal'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(item.$2),
                      selected: _category == item.$1,
                      onSelected: (_) => setState(() => _category = item.$1),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _range,
                  );
                  if (range != null) setState(() => _range = range);
                },
                icon: const Icon(Icons.date_range),
                label: Text(_range == null ? 'Filter by date' : '${_dateLabel(_range!.start)} – ${_dateLabel(_range!.end)}'),
              ),
              if (_range != null) TextButton(onPressed: () => setState(() => _range = null), child: const Text('Clear')),
            ]),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              const Padding(padding: EdgeInsets.all(18), child: Text('Could not open the encrypted record store. Check device storage and key access.'))
            else if (records.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE8E8F2))),
                child: Column(children: [
                  const Icon(Icons.filter_list_off, size: 38, color: Color(0xFF7938DB)),
                  const SizedBox(height: 10),
                  Text(all.isEmpty ? 'Your health record starts here' : 'No matching records',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 6),
                  Text(all.isEmpty ? 'Add a checkup, vital sign, medication or medical document to begin.' : 'Try another category, search term or date range.',
                    textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.4)),
                ]),
              )
            else ...grouped.entries.map((group) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 9),
                  child: Row(children: [
                    Text(group.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1, color: const Color(0xFFE7E7F0))),
                    const SizedBox(width: 8),
                    Text('${group.value.length}', style: const TextStyle(fontSize: 11, color: muted)),
                  ]),
                ),
                ...group.value.map((record) => Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECECF4))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(_iconFor(record.resourceType), size: 19, color: const Color(0xFF7938DB)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_title(record), style: const TextStyle(fontWeight: FontWeight.w800, color: ink))),
                      Text(_eventDate(record).toLocal().toString().substring(11, 16), style: const TextStyle(fontSize: 12, color: muted)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_summary(record), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, height: 1.35)),
                    const SizedBox(height: 7),
                    Row(children: [
                      const Expanded(child: Text('PATIENT-ENTERED · UNVERIFIED', style: TextStyle(fontSize: 9, letterSpacing: .5, fontWeight: FontWeight.w800, color: Color(0xFF8A6C24)))),
                      TextButton(onPressed: () => _showDetails(record, all), child: const Text('Details')),
                      if (!{'encounter', 'document_reference'}.contains(record.resourceType))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit',
                          onPressed: () async {
                            if (record.resourceType == 'patient_profile') return;
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ClinicalRecordForm(kind: _editKind(record.resourceType), existing: record)));
                            await _refresh();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                            title: const Text('Delete this record?'),
                            content: const Text('This removes the local record. Any previously synchronized copy is not affected.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ));
                          if (confirmed == true) {
                            await patientRecords.delete(record);
                            if (record.resourceType == 'document_reference') {
                              final blobId = record.payload['encrypted_blob_id'];
                              if (blobId is String) await encryptedDocuments.delete(blobId);
                            }
                            await _refresh();
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ]),
                  ]),
                )),
              ],
            )),
            const SizedBox(height: 12),
            const Text('Your profile is managed separately. Timeline entries are patient-entered unless an authorized verification process is introduced.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.4)),
          ],
        ),
      );
    },
  );

  static IconData _iconFor(String type) => switch (type) {
    'encounter' => Icons.medical_services_outlined,
    'observation' => Icons.monitor_heart_outlined,
    'medication_statement' || 'medication_dose_log' => Icons.medication_outlined,
    'allergy' => Icons.warning_amber_outlined,
    'condition' => Icons.health_and_safety_outlined,
    'document_reference' => Icons.description_outlined,
    'symptom_entry' => Icons.healing_outlined,
    'health_journal' => Icons.edit_note,
    _ => Icons.folder_outlined,
  };

  static String _editKind(String type) => switch (type) {
    'observation' => 'Vitals',
    'medication_statement' => 'Medication',
    'allergy' => 'Allergies',
    'condition' => 'Conditions',
    _ => 'Vitals',
  };
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onAdd});
  final VoidCallback onAdd;
  static const ink = Color(0xFF171B3D);
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
    children: [
      Row(children: [
        Image.asset('assets/ujexa_health_mark.png', width: 42, height: 42, fit: BoxFit.contain),
        const SizedBox(width: 8),
        const Text('Ujexa Health', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
        const Spacer(),
        IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationCenterPage())), icon: const Icon(Icons.notifications_none)),
        const CircleAvatar(backgroundColor: Color(0xFFE9DDFF), child: Text('K', style: TextStyle(color: ink))),
      ]),
      const SizedBox(height: 20),
      const Text('Your health, in one place', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 5),
      const Text('A clearer picture begins with the information you choose to keep.', style: TextStyle(color: Color(0xFF69708E))),
      const SizedBox(height: 20),
      FutureBuilder<List<PatientRecord>>(
        future: patientRecords.readAll(),
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFFF3EAFF), Color(0xFFE2D9FF)]),
            ),
            child: Row(children: [
              const Icon(Icons.favorite_outline, size: 42, color: Color(0xFF7938DB)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your personal health record', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 4),
                Text(snapshot.hasError ? 'Encrypted storage is currently unavailable.' : '$count patient-entered record${count == 1 ? '' : 's'} on this device.',
                  style: const TextStyle(color: Color(0xFF69708E))),
              ])),
            ]),
          );
        },
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECECF4))),
        child: const Text('Your records are encrypted on this device. Entries you create are labelled patient-reported until an authorized verification process is available.',
          style: TextStyle(color: Color(0xFF69708E), height: 1.4)),
      ),
      const SizedBox(height: 24),
      const Text('Quick actions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 12),
      Wrap(spacing: 9, runSpacing: 9, children: [
        QuickAction(icon: Icons.favorite, label: 'Log vitals', color: const Color(0xFFFFF0F4), onTap: () => _open(context, 'Vitals')),
        QuickAction(icon: Icons.medication_outlined, label: 'Medication log', color: const Color(0xFFF0EAFE), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationManagementPage()))),
        QuickAction(icon: Icons.document_scanner_outlined, label: 'Scan document', color: const Color(0xFFE9F5FF), onTap: () => _open(context, 'Medical document')),
        QuickAction(icon: Icons.medical_services_outlined, label: 'Log checkup', color: const Color(0xFFFFF0E8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckupForm()))),
        QuickAction(icon: Icons.grid_view_rounded, label: 'More', color: const Color(0xFFF1F3FF), onTap: onAdd),
      ]),
    ],
  );
  static void _open(BuildContext context, String name) => Navigator.push(context, MaterialPageRoute(builder: (_) => ClinicalRecordForm(kind: name)));
}


class _Stage15InsightBundle {
  const _Stage15InsightBundle(this.insights,this.network,this.adherence);
  final HealthInsightSnapshot insights;
  final HealthNetworkResult network;
  final MedicationAdherenceSnapshot adherence;
}

class HealthInsightsPage extends StatefulWidget {
  const HealthInsightsPage({super.key});
  @override
  State<HealthInsightsPage> createState() => _HealthInsightsPageState();
}

class _HealthInsightsPageState extends State<HealthInsightsPage> {
  static const ink = Color(0xFF171B3D);
  static const muted = Color(0xFF69708E);
  late Future<_Stage15InsightBundle> _future;

  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_Stage15InsightBundle> _load() async {
    final records = await patientRecords.readAll();
    final insights = HealthInsightsEngine.analyze(records.map((r) => r.payload).toList());
    final network = LongitudinalHealthNetwork().analyze(records);
    final adherence = MedicationAdherenceEngine.analyze(records);
    return _Stage15InsightBundle(insights,network,adherence);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
    ]),
  );

  Widget _adherenceMetric(String label, int count, Color color) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: muted)),
    ]),
  );

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECECF4))),
    child: child,
  );

  String _date(dynamic raw) {
    final date = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (date == null) return 'Date not recorded';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Stage15InsightBundle>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 40, color: Color(0xFF7938DB)),
            const SizedBox(height: 10),
            const Text('Insights are unavailable', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 6),
            const Text('The encrypted health record could not be read on this device.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ]),
        ));
      }
      final bundle = snapshot.data!;
      final data = bundle.insights;
      final network = bundle.network;
      final adherence = bundle.adherence;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
          children: [
            const Text('Health insights', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 6),
            const Text('Descriptive summaries from the information you have recorded.', style: TextStyle(color: muted)),
            const SizedBox(height: 16),
            _panel(child: Row(children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF7938DB), size: 28),
              const SizedBox(width: 12),
              const Expanded(child: Text('Insights are calculated on this device from your decrypted records. They are not diagnoses or treatment advice.', style: TextStyle(color: muted, height: 1.4, fontSize: 12))),
            ])),
            _sectionTitle('Cross-domain intelligence', 'Explore dated overlaps across symptoms, measurements, medication events, visits and documents.'),
            const CrossDomainHealthPanel(),
            _sectionTitle('Symptoms & daily journal', 'Review recurring entries and your own day-to-day ratings.'),
            const SymptomJournalInsightsPanel(),
            _sectionTitle('Personal health intelligence', 'A private model studies changes in your own recorded history.'),
            _panel(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFFF0EAFE),borderRadius:BorderRadius.circular(14)),
                  child:const Icon(Icons.hub_outlined,color:Color(0xFF7938DB),size:25)),
                const SizedBox(width:11),
                const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('Longitudinal neural model',style:TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:16)),
                  Text('On-device · patient-specific · self-supervised',style:TextStyle(fontSize:11,color:muted))
                ]))
              ]),
              const SizedBox(height:12),
              if(!network.ready) ...[
                Text('${network.historyDays}/${LongitudinalHealthNetwork.minHistoryDays} distinct measurement days',style:const TextStyle(fontWeight:FontWeight.w800,color:ink)),
                const SizedBox(height:7),
                ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:(network.historyDays/LongitudinalHealthNetwork.minHistoryDays).clamp(0.0,1.0),minHeight:7,backgroundColor:const Color(0xFFECEAF3),color:const Color(0xFF7938DB))),
                const SizedBox(height:7),Text(network.limitations,style:const TextStyle(fontSize:12,color:muted))
              ] else ...[
                Row(children:[
                  Icon(network.personalPatternChanged?Icons.insights:Icons.check_circle_outline,color:network.personalPatternChanged?const Color(0xFFB36A17):const Color(0xFF27866D)),
                  const SizedBox(width:7),Expanded(child:Text(network.personalPatternChanged?'Personal pattern changed':'Personal pattern broadly consistent',style:const TextStyle(fontWeight:FontWeight.w800,color:ink)))
                ]),
                const SizedBox(height:7),Text(network.summary,style:const TextStyle(fontSize:12,color:muted,height:1.4)),
                const SizedBox(height:6),Text('${network.historyDays} history days · ${network.trainingDays} baseline days · ${network.evaluatedDays} recent days',style:const TextStyle(fontSize:10,color:muted))
              ],
              const SizedBox(height:8),Text(network.limitations,style:const TextStyle(fontSize:10,color:muted))
            ])),
            _sectionTitle('Medication adherence', 'Dose events compared with the explicit schedules you recorded.'),
            _panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Expanded(child:Text(adherence.adherencePercent==null?'No completed dose history': '${adherence.adherencePercent!.toStringAsFixed(0)}% recorded as taken',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:ink))),
                Text('${adherence.taken} taken',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:Color(0xFF27866D)))
              ]),
              const SizedBox(height:10),
              Row(children:[
                _adherenceMetric('Missed',adherence.missed,const Color(0xFFD45A47)),
                _adherenceMetric('Skipped',adherence.skipped,const Color(0xFFB36A17)),
                _adherenceMetric('Overdue',adherence.overdue,const Color(0xFF7938DB)),
                _adherenceMetric('Upcoming',adherence.upcoming,const Color(0xFF3977D5)),
              ]),
              const SizedBox(height:8),
              const Divider(height:20),
              const Text('Recent and upcoming doses',style:TextStyle(fontWeight:FontWeight.w800,color:ink)),
              const SizedBox(height:7),
              ...adherence.doses.take(8).map((dose){
                final color=switch(dose.state){DoseState.taken=>const Color(0xFF27866D),DoseState.missed=>const Color(0xFFD45A47),DoseState.skipped=>const Color(0xFFB36A17),DoseState.overdue=>const Color(0xFFD45A47),DoseState.upcoming=>const Color(0xFF3977D5)};
                return Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[
                  Icon(switch(dose.state){DoseState.taken=>Icons.check_circle,DoseState.missed=>Icons.cancel,DoseState.skipped=>Icons.remove_circle_outline,DoseState.overdue=>Icons.warning_amber_rounded,DoseState.upcoming=>Icons.alarm},size:17,color:color),
                  const SizedBox(width:8),Expanded(child:Text('${dose.medicationName} · ${dose.dose}',style:const TextStyle(fontSize:11,color:ink))),
                  Text('${dose.dueAt.month}/${dose.dueAt.day} ${dose.dueAt.hour.toString().padLeft(2,'0')}:${dose.dueAt.minute.toString().padLeft(2,'0')}',style:const TextStyle(fontSize:10,color:muted)),
                  const SizedBox(width:5),Text(dose.state.name,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:color))
                ]));
              }),
              const Text('Overdue doses are not automatically logged as missed. Confirm each event in Medication Management. This percentage describes recorded events only.',style:TextStyle(fontSize:11,color:muted,height:1.35))
            ])),
            _sectionTitle('Vital-sign history', 'Recorded measurements over time; units are kept separate.'),
            if (data.vitalTrends.isEmpty)
              _panel(child: const Text('No usable numeric observations yet. Add measurements on the Records tab to see history here.', style: TextStyle(color: muted, height: 1.4)))
            else ...data.vitalTrends.map((trend) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(trend.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink))),
                  Text('${trend.latestValue.toStringAsFixed(2)} ${trend.unit}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF7938DB))),
                ]),
                const SizedBox(height: 4),
                Text('${trend.points.length} measurement${trend.points.length == 1 ? '' : 's'} · ${_date(trend.points.first.date.toIso8601String())} to ${_date(trend.points.last.date.toIso8601String())}',
                  style: const TextStyle(fontSize: 11, color: muted)),
                const SizedBox(height: 12),
                if (trend.points.length > 1) SizedBox(height: 68, width: double.infinity, child: CustomPaint(painter: _TrendPainter(trend.points.map((p) => p.value).toList()))),
                const SizedBox(height: 7),
                Text(HealthInsightsEngine.describeChange(trend), style: const TextStyle(fontSize: 12, color: muted, height: 1.4)),
              ])),
            )),
            _sectionTitle('Medication overview', 'Based on the status recorded in each medication statement.'),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data.activeMedications.length} active medication${data.activeMedications.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
              Text('${data.otherMedicationCount} with another or unspecified status', style: const TextStyle(fontSize: 12, color: muted)),
              if (data.activeMedications.isNotEmpty) ...[
                const Divider(height: 22),
                ...data.activeMedications.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.medication_outlined, size: 18, color: Color(0xFF7938DB)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((m['medication_name'] ?? 'Medication').toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                      Text([m['dose'], m['frequency']].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: muted)),
                    ])),
                  ]),
                )),
              ],
            ])),
            _sectionTitle('Recorded allergies and conditions', 'Only entries currently marked active are included.'),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Active allergies · ${data.activeAllergies.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
              if (data.activeAllergies.isNotEmpty) ...data.activeAllergies.map((r) => Padding(padding: const EdgeInsets.only(top: 5), child: Text('• ${r['substance'] ?? 'Unspecified'}${r['severity'] == null ? '' : ' · ${r['severity']}'}', style: const TextStyle(color: muted)))),
              const Divider(height: 22),
              Text('Active conditions · ${data.activeConditions.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
              if (data.activeConditions.isNotEmpty) ...data.activeConditions.map((r) => Padding(padding: const EdgeInsets.only(top: 5), child: Text('• ${r['display'] ?? 'Unspecified'}', style: const TextStyle(color: muted)))),
              if (data.activeAllergies.isEmpty && data.activeConditions.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 6), child: Text('No active allergies or conditions are recorded. This does not confirm their absence.', style: TextStyle(fontSize: 12, color: muted))),
            ])),
            _sectionTitle('Checkup history and follow-up notes', 'Recent encounters and instructions already saved in your records.'),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (data.recentVisits.isEmpty) const Text('No checkups recorded yet.', style: TextStyle(color: muted))
              else ...data.recentVisits.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.event_note_outlined, size: 18, color: Color(0xFF7938DB)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((r['reason'] ?? r['encounter_type'] ?? 'Visit').toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                    Text('${_date(r['started_at'])} · ${(r['organization'] ?? 'Facility not recorded')}', style: const TextStyle(fontSize: 11, color: muted)),
                  ])),
                ]),
              )),
              if (data.followUpItems.isNotEmpty) ...[
                const Divider(height: 18),
                const Text('Recorded follow-up instructions', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
                ...data.followUpItems.map((v) => Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $v', style: const TextStyle(color: muted, height: 1.35)))),
              ] else
                const Text('No follow-up instructions have been recorded. This is not a reminder system.', style: TextStyle(fontSize: 12, color: muted)),
            ])),
            _sectionTitle('Data completeness', 'Gaps that limit what can be summarized.'),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data.totalRecords} clinical record${data.totalRecords == 1 ? '' : 's'} analyzed', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 7),
              ...data.dataQualityNotes.map((note) => Padding(padding: const EdgeInsets.only(top: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF9A741B)),
                const SizedBox(width: 7),
                Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: muted, height: 1.35))),
              ]))),
              if (data.dataQualityNotes.isEmpty) const Text('No obvious missing fields were detected in the records used for these summaries.', style: TextStyle(fontSize: 12, color: muted)),
            ])),
            const SizedBox(height: 18),
            const Text('These summaries reflect only what is stored in this personal record. Missing entries, outdated information or incorrect measurements can change the picture. Do not use this page to make medical decisions or change medication without a qualified professional.',
              style: TextStyle(fontSize: 11, color: muted, height: 1.45)),
          ],
        ),
      );
    },
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final spread = maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = spread == 0 ? .5 : (values[i] - minValue) / spread;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    final line = Paint()..color = const Color(0xFF7938DB)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dot = Paint()..color = const Color(0xFF7938DB);
    canvas.drawPath(path, line);
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = spread == 0 ? .5 : (values[i] - minValue) / spread;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 3.5, dot);
    }
  }
  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.values != values;
}

class OverviewCard extends StatelessWidget {
  const OverviewCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(colors: [Color(0xFFF3EAFF), Color(0xFFE2D9FF)]),
    ),
    child: Row(children: [
      SizedBox(width: 132, height: 132, child: Stack(alignment: Alignment.center, children: [
        const SizedBox.expand(child: CircularProgressIndicator(value: .85, strokeWidth: 11, backgroundColor: Color(0xFFD8C4F2), color: Color(0xFF9638E8))),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.favorite, color: Color(0xFFC44BC5), size: 24),
          Text('85%', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
          Text('Daily progress', style: TextStyle(fontSize: 11)),
        ]),
      ])),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You’re on track!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
        SizedBox(height: 10),
        Text('✓  Medication taken', style: TextStyle(height: 1.8)),
        Text('✓  Vitals logged', style: TextStyle(height: 1.8)),
        Text('○  Stay active (20 min)', style: TextStyle(height: 1.8)),
      ])),
    ]),
  );
}

class MetricCard extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color tint;
  const MetricCard({super.key, required this.icon, required this.value, required this.label, required this.tint});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      Icon(icon, color: const Color(0xFF7938DB), size: 25),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF69708E))),
    ]),
  );
}

class FeatureCard extends StatelessWidget {
  final IconData icon; final String title; final String detail; final String foot; final Color tint;
  const FeatureCard({super.key, required this.icon, required this.title, required this.detail, required this.foot, required this.tint});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEEEFF6))),
    child: Row(children: [
      CircleAvatar(backgroundColor: tint, foregroundColor: const Color(0xFF7938DB), child: Icon(icon)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
        const SizedBox(height: 4), Text(detail), Text(foot, style: const TextStyle(fontSize: 11, color: Color(0xFF69708E))),
      ])),
      const Icon(Icons.chevron_right),
    ]),
  );
}

class QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const QuickAction({super.key, required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(width: 132, child: Material(
    color: color, borderRadius: BorderRadius.circular(18), child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(18),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8), child: Column(children: [
        Icon(icon, color: const Color(0xFF7938DB), size: 26), const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ])),
    ),
  ));
}


class DocumentPromotionWorkspace extends StatefulWidget {
  const DocumentPromotionWorkspace({super.key});
  @override State<DocumentPromotionWorkspace> createState()=>_DocumentPromotionWorkspaceState();
}
class _DocumentPromotionWorkspaceState extends State<DocumentPromotionWorkspace>{
  late Future<List<PatientRecord>> _future;
  final Map<String,TextEditingController> _edits={};
  bool _saving=false;
  @override void initState(){super.initState();_future=patientRecords.readAll();}
  @override void dispose(){for(final c in _edits.values){c.dispose();}super.dispose();}
  TextEditingController _controller(String key,String value)=>_edits.putIfAbsent(key,()=>TextEditingController(text:value));
  Future<void> _promote(PatientRecord doc,Map<String,dynamic> annotation)async{
    final fields=Map<String,String>.from(annotation['fields'] as Map);
    final kind=annotation['kind'] as String;
    final key='${doc.id}:${doc.version}:${annotation['page']}:${annotation['evidence']}';
    final evidence=annotation['evidence'] as String;
    final page=annotation['page'] as int;
    final provenance={
      'source':'imported_document','source_document_id':doc.id,
      'source_reference':'page:$page','verification_status':'patient_confirmed',
      'recorded_at':DateTime.now().toUtc().toIso8601String(),
      'notes':'Patient reviewed and confirmed this extracted candidate. Original evidence: $evidence',
    };
    setState(()=>_saving=true);
    try{
      if(kind=='lab_result_candidate'){
        final name=_controller('$key:name',fields['test_name']??'').text.trim();
        final value=_controller('$key:value',fields['value']??'').text.trim();
        final unit=value.split(RegExp(r'\s+')).skip(1).join(' ');
        final number=double.tryParse(value.split(RegExp(r'\s+')).first.replaceAll(',','.'));
        if(name.isEmpty||value.isEmpty||number==null)throw const FormatException('Enter a valid test name and numeric result.');
        await patientRecords.create(resourceType:'observation',recordedAt:DateTime.now().toUtc(),fields:{
          'code':name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_'),
          'display':name,'effective_at':doc.payload['document_date']!=null?DateTime.parse(doc.payload['document_date']).toUtc().toIso8601String():DateTime.now().toUtc().toIso8601String(),
          'value_quantity':number,'unit':unit,'notes':'Promoted from document ${doc.payload['title']}. Evidence: $evidence. ${fields['reference_range']??''}',
          'source_document_id':doc.id,'source_page':page,'source_evidence':evidence,'provenance':provenance,
        });
      }else if(kind=='medication_instruction_candidate'){
        final name=_controller('$key:medname','').text.trim();
        final strength=_controller('$key:strength','').text.trim();
        final instruction=_controller('$key:instruction',fields['instruction_text']??'').text.trim();
        if(name.isEmpty||instruction.isEmpty)throw const FormatException('Enter the medication name and confirm the instruction.');
        await patientRecords.create(resourceType:'medication_statement',recordedAt:DateTime.now().toUtc(),fields:{
          'medication_name':name,'strength':strength,'dose':instruction,'frequency':'','dose_times':[],
          'status':'unknown','notes':'Imported instruction requires clinician/patient clarification before any reminder schedule. Source document: ${doc.payload['title']}. Evidence: $evidence',
          'source_document_id':doc.id,'source_page':page,'source_evidence':evidence,'provenance':provenance,
        });
      }else{
        throw const FormatException('Date candidates are retained on the document and are not promoted as clinical observations.');
      }
      final updated=List<Map<String,dynamic>>.from(doc.payload['accepted_document_annotations'] as List);
      for(var i=0;i<updated.length;i++){
        if(updated[i]['evidence']==evidence&&updated[i]['kind']==kind&&updated[i]['page']==page){
          updated[i]={...updated[i],'status':'promoted_patient_confirmed','promoted_at':DateTime.now().toUtc().toIso8601String()};
          break;
        }
      }
      await patientRecords.update(doc,fields:{...doc.payload,'accepted_document_annotations':updated});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Confirmed information added to your health records.')));setState(()=>_future=patientRecords.readAll());}
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e is FormatException?e.message:'Could not promote this candidate.')));
    }finally{if(mounted)setState(()=>_saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Document review workspace')),
    body:FutureBuilder<List<PatientRecord>>(future:_future,builder:(context,snapshot){
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      final docs=snapshot.data!.where((r)=>r.resourceType=='document_reference'&&r.payload['accepted_document_annotations'] is List).toList();
      final pending=<({PatientRecord doc,Map<String,dynamic> annotation})>[];
      for(final doc in docs){for(final raw in (doc.payload['accepted_document_annotations'] as List)){
        final a=Map<String,dynamic>.from(raw as Map);
        if(a['status']=='patient_accepted_unverified')pending.add((doc:doc,annotation:a));
      }}
      if(pending.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('No unreviewed document annotations. Extract and accept candidates from a medical document first.',textAlign:TextAlign.center)));
      return ListView(padding:const EdgeInsets.all(18),children:[
        const Text('Confirm extracted information',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
        const SizedBox(height:6),
        const Text('Each item is reviewed independently. Confirmed values become patient-confirmed records, not clinician-verified records.',style:TextStyle(color:Color(0xFF69708E))),
        const SizedBox(height:16),
        ...pending.map((item){
          final doc=item.doc;final a=item.annotation;final fields=Map<String,String>.from(a['fields'] as Map);final kind=a['kind'];
          final evidence=a['evidence'];final page=a['page'];
          return Container(margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFFEAE8F1))),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(doc.payload['title']??'Medical document',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:15,color:Color(0xFF171B3D))),
              Text('Page $page · ${kind.toString().replaceAll('_',' ')}',style:const TextStyle(fontSize:11,color:Color(0xFF7938DB))),
              const SizedBox(height:8),
              Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFFF5F2FA),borderRadius:BorderRadius.circular(10)),child:Text('Source evidence: $evidence',style:const TextStyle(fontSize:12))),
              const SizedBox(height:10),
              if(kind=='lab_result_candidate')...[
                TextField(controller:_controller('${doc.id}:$page:$evidence:name',fields['test_name']??''),decoration:const InputDecoration(labelText:'Test name',border:OutlineInputBorder())),
                const SizedBox(height:8),
                TextField(controller:_controller('${doc.id}:$page:$evidence:value',fields['value']??''),decoration:const InputDecoration(labelText:'Result and unit',border:OutlineInputBorder())),
                if(fields['reference_range']!=null)Text('Source reference range: ${fields['reference_range']}',style:const TextStyle(fontSize:11)),
              ]else if(kind=='medication_instruction_candidate')...[
                TextField(controller:_controller('${doc.id}:$page:$evidence:medname',''),decoration:const InputDecoration(labelText:'Medication name (required)',border:OutlineInputBorder())),
                const SizedBox(height:8),
                TextField(controller:_controller('${doc.id}:$page:$evidence:strength',''),decoration:const InputDecoration(labelText:'Strength (optional)',border:OutlineInputBorder())),
                const SizedBox(height:8),
                TextField(controller:_controller('${doc.id}:$page:$evidence:instruction',fields['instruction_text']??''),decoration:const InputDecoration(labelText:'Instruction text',border:OutlineInputBorder())),
              ]else
                const Text('Date candidates remain attached to the source document until a dedicated date-confirmation workflow is available.',style:TextStyle(fontSize:12)),
              const SizedBox(height:10),
              if(kind!='document_date_candidate')FilledButton.icon(onPressed:_saving?null:()=>_promote(doc,a),icon:const Icon(Icons.verified_outlined),label:const Text('Confirm and add to health records')),
              if(kind=='document_date_candidate')const Text('Not promotable yet',style:TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF8A6B32))),
            ]),
          );
        }),
      ]);
    }),
  );
}


class StageCaptureForm extends StatefulWidget {
  const StageCaptureForm({super.key,required this.kind});
  final String kind;
  @override State<StageCaptureForm> createState()=>_StageCaptureFormState();
}
class _StageCaptureFormState extends State<StageCaptureForm>{
  final a=TextEditingController(),b=TextEditingController(),c=TextEditingController();
  DateTime date=DateTime.now();String category='nutrition',status='unknown';final Set<String> selected={'medications','allergies','conditions'};
  bool saving=false;
  @override void dispose(){a.dispose();b.dispose();c.dispose();super.dispose();}
  Future<void> save()async{
    setState(()=>saving=true);
    try{
      final type=switch(widget.kind){'Appointment'=>'appointment','Lifestyle entry'=>'lifestyle_entry','Preventive care'=>'preventive_care',_=>'sharing_consent'};
      final fields=switch(type){
        'appointment'=>{'title':a.text.trim(),'appointment_at':date.toUtc().toIso8601String(),'provider_name':b.text.trim(),'location':c.text.trim(),'status':'planned'},
        'lifestyle_entry'=>{'category':category,'occurred_at':date.toUtc().toIso8601String(),'summary':a.text.trim(),'numeric_value':double.tryParse(b.text.trim()),'unit':c.text.trim()},
        'preventive_care'=>{'item':a.text.trim(),'due_date':date.toIso8601String().split('T').first,'status':status,'notes':b.text.trim()},
        _=>{'recipient':a.text.trim(),'purpose':b.text.trim(),'included_categories':selected.toList(),'granted_at':DateTime.now().toUtc().toIso8601String(),'status':'active','expires_at':date.toUtc().toIso8601String()},
      };
      await patientRecords.create(resourceType:type,fields:fields);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved securely on this device.')));Navigator.pop(context);}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.kind)),body:ListView(padding:const EdgeInsets.all(20),children:[
    Text(widget.kind,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
    const SizedBox(height:12),
    if(widget.kind=='Appointment')...[
      TextField(controller:a,decoration:const InputDecoration(labelText:'Appointment title',border:OutlineInputBorder())),
      const SizedBox(height:10),TextField(controller:b,decoration:const InputDecoration(labelText:'Clinician / provider',border:OutlineInputBorder())),
      const SizedBox(height:10),TextField(controller:c,decoration:const InputDecoration(labelText:'Location',border:OutlineInputBorder())),
    ]else if(widget.kind=='Lifestyle entry')...[
      DropdownButtonFormField(value:category,decoration:const InputDecoration(labelText:'Category'),items:const ['nutrition','activity','sleep','hydration','other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v??'nutrition')),
      const SizedBox(height:10),TextField(controller:a,decoration:const InputDecoration(labelText:'Describe the entry',border:OutlineInputBorder())),
      const SizedBox(height:10),TextField(controller:b,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Optional numeric amount',border:OutlineInputBorder())),
      const SizedBox(height:10),TextField(controller:c,decoration:const InputDecoration(labelText:'Unit (optional)',border:OutlineInputBorder())),
    ]else if(widget.kind=='Preventive care')...[
      TextField(controller:a,decoration:const InputDecoration(labelText:'Screening / vaccination / preventive item',border:OutlineInputBorder())),
      const SizedBox(height:10),DropdownButtonFormField(value:status,decoration:const InputDecoration(labelText:'Status'),items:const ['unknown','due','scheduled','completed','not_applicable'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>status=v??'unknown')),
      const SizedBox(height:10),TextField(controller:b,decoration:const InputDecoration(labelText:'Notes',border:OutlineInputBorder())),
    ]else...[
      TextField(controller:a,decoration:const InputDecoration(labelText:'Recipient (clinician / organization)',border:OutlineInputBorder())),
      const SizedBox(height:10),TextField(controller:b,decoration:const InputDecoration(labelText:'Purpose of sharing',border:OutlineInputBorder())),
      const Text('Select categories to authorize',style:TextStyle(fontWeight:FontWeight.w700)),
      ...['profile','conditions','allergies','medications','observations','encounters','documents','symptoms'].map((x)=>CheckboxListTile(value:selected.contains(x),title:Text(x),dense:true,onChanged:(v)=>setState(()=>v==true?selected.add(x):selected.remove(x)))),
      const Text('This records local consent intent only. It does not transmit records or create a secure clinician portal link.',style:TextStyle(fontSize:12,color:Color(0xFF69708E))),
    ],
    const SizedBox(height:12),
    OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setState(()=>date=d);},icon:const Icon(Icons.calendar_today),label:Text('Date: ${date.toLocal().toString().split(' ').first}')),
    const SizedBox(height:16),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save securely')),
  ]));
}



class SharingConsentPage extends StatefulWidget {
 const SharingConsentPage({super.key});
 @override State<SharingConsentPage> createState()=>_SharingConsentPageState();
}
class _SharingConsentPageState extends State<SharingConsentPage>{
 late Future<List<PatientRecord>> future;
 @override void initState(){super.initState();future=patientRecords.readAll();}
 Future<void> revoke(PatientRecord r)async{
  await patientRecords.update(r,fields:{...r.payload,'status':'revoked','revoked_at':DateTime.now().toUtc().toIso8601String()});
  setState(()=>future=patientRecords.readAll());
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Sharing consent')),body:FutureBuilder<List<PatientRecord>>(future:future,builder:(context,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final consents=s.data!.where((r)=>r.resourceType=='sharing_consent').toList();
  if(consents.isEmpty)return const Center(child:Text('No local sharing consent records.'));
  return ListView(padding:const EdgeInsets.all(18),children:consents.map((r)=>Card(child:ListTile(
   title:Text(r.payload['recipient']??'Recipient'),
   subtitle:Text('${r.payload['purpose']}\\n${(r.payload['included_categories'] as List).join(', ')}\\nStatus: ${r.payload['status']}'),
   isThreeLine:true,
   trailing:r.payload['status']=='active'?TextButton(onPressed:()=>revoke(r),child:const Text('Revoke')):const Icon(Icons.lock_outline),
  ))).toList());
 }));
}

class RecordHistoryPage extends StatefulWidget {
 const RecordHistoryPage({super.key});
 @override State<RecordHistoryPage> createState()=>_RecordHistoryPageState();
}
class _RecordHistoryPageState extends State<RecordHistoryPage>{
 late Future<List<PatientRecord>> future;
 @override void initState(){super.initState();future=patientRecords.readAll();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Record history')),body:FutureBuilder<List<PatientRecord>>(future:future,builder:(context,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final records=s.data!;
  return ListView(padding:const EdgeInsets.all(18),children:[
   const Text('Current record versions',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800)),
   const Text('Records are stored as immutable versions. Earlier versions can be inspected where the encrypted store retains them.',style:TextStyle(color:Color(0xFF69708E))),
   ...records.map((r)=>ListTile(title:Text('${r.resourceType} · v${r.version}'),subtitle:Text('${r.id}\\n${r.recordedAt.toLocal()}'),isThreeLine:true,
    trailing:IconButton(icon:const Icon(Icons.history),onPressed:()async{
      final previous=<PatientRecord>[];
      for(var v=1;v<r.version;v++){final old=await patientRecords.read(r.id,version:v);if(old!=null)previous.add(old);}
      if(!context.mounted)return;
      showModalBottomSheet(context:context,builder:(_)=>SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
       Text('Version history · ${r.resourceType}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
       ...previous.map((x)=>ListTile(title:Text('Version ${x.version}'),subtitle:Text(x.recordedAt.toLocal().toString()))),
       ListTile(title:Text('Current · Version ${r.version}'),subtitle:Text(r.recordedAt.toLocal().toString())),
      ])));
    }))),
  ]);
 }));
}

class RecordIntegrityPage extends StatefulWidget {
 const RecordIntegrityPage({super.key});
 @override State<RecordIntegrityPage> createState()=>_RecordIntegrityPageState();
}
class _RecordIntegrityPageState extends State<RecordIntegrityPage>{
 late Future<List<PatientRecord>> future;
 @override void initState(){super.initState();future=patientRecords.readAll();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Record integrity')),body:FutureBuilder<List<PatientRecord>>(future:future,builder:(context,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final report=RecordIntegrity.analyze(s.data!);
  return ListView(padding:const EdgeInsets.all(20),children:[
   Text('${report.recordsReviewed} records reviewed',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800)),
   const Text('Local checks for possible duplicates and conflicting measurements. Findings are review prompts, not automatic corrections.',style:TextStyle(color:Color(0xFF69708E))),
   const SizedBox(height:16),
   if(report.findings.isEmpty)const Text('No possible duplicates or conflicting measurements detected by the current rules.'),
   ...report.findings.map((f)=>Card(child:ListTile(leading:Icon(f.kind=='conflicting_measurements'?Icons.warning_amber:Icons.copy_outlined),title:Text(f.title),subtitle:Text('${f.detail}\\n${f.recordIds.length} records involved')))),
  ]);
 }));
}

class EmergencySummaryPage extends StatefulWidget {
 const EmergencySummaryPage({super.key});
 @override State<EmergencySummaryPage> createState()=>_EmergencySummaryPageState();
}
class _EmergencySummaryPageState extends State<EmergencySummaryPage>{
 late Future<List<PatientRecord>> future;
 @override void initState(){super.initState();future=patientRecords.readAll();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Emergency health summary')),body:FutureBuilder<List<PatientRecord>>(future:future,builder:(context,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final all=s.data!;final profiles=all.where((r)=>r.resourceType=='patient_profile').toList();final profile=profiles.isEmpty?null:profiles.first;
  final items=all.where((r)=>['allergy','condition','medication_statement'].contains(r.resourceType)&&r.payload['status']!='stopped'&&r.payload['status']!='resolved').toList();
  Widget section(String title,List<Widget> children)=>Padding(padding:const EdgeInsets.only(bottom:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),...children]));
  return ListView(padding:const EdgeInsets.all(20),children:[
   const Text('Emergency health summary',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
   const Text('A locally stored summary for the patient to review and share. Not an emergency dispatch service.',style:TextStyle(color:Color(0xFF69708E))),
   section('Patient', [Text(profile?.payload['preferred_name']??'Name not recorded'),Text('Blood group: ${profile?.payload['blood_group']??'Not recorded'}'),Text('Emergency contact: ${profile?.payload['emergency_contact_name']??'Not recorded'} · ${profile?.payload['emergency_contact_phone']??''}')]),
   section('Relevant records',items.map((r)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(r.payload['medication_name']??r.payload['substance']??r.payload['display']??r.resourceType),subtitle:Text(r.resourceType))).toList()),
   const Text('Keep this summary current. Information may be incomplete or unverified. No data is automatically sent to emergency services.',style:TextStyle(fontSize:12,color:Color(0xFF69708E))),
  ]);
 }));
}

class AddRecordSheet extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const AddRecordSheet({super.key, required this.onSelect});
  static const actions = ['Manage sharing consent','Record history','Record integrity','Emergency summary','Appointment','Lifestyle entry','Preventive care','Share health records','Review document extractions','Symptoms','Journal','Medication','Medication log','Vitals','Allergies','Conditions','Meal','Activity','Sleep','Medical document','Voice note','Log checkup'];
  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .88,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFC7BFDC), borderRadius: BorderRadius.circular(5))),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('Add to your health record', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF171B3D)))),
          const SizedBox(height: 12),
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 116, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.0,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return Material(color: const Color(0xFFF1EAFF), borderRadius: BorderRadius.circular(18), child: InkWell(
                borderRadius: BorderRadius.circular(18), onTap: () => onSelect(action),
                child: Padding(padding: const EdgeInsets.all(8), child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icon(action), color: const Color(0xFF7938DB), size: 27),
                    const SizedBox(height: 7),
                    Flexible(child: Text(action, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                )),
              ));
            },
          )),
        ]),
      ),
    ),
  );
  static IconData _icon(String s) => switch(s) {
    'Symptoms' => Icons.health_and_safety_outlined, 'Journal' => Icons.edit_note, 'Medication' => Icons.medication_outlined, 'Medication log' => Icons.medication_outlined,
    'Vitals' => Icons.water_drop_outlined, 'Meal' => Icons.restaurant_outlined,
    'Activity' => Icons.directions_run, 'Sleep' => Icons.bedtime_outlined,
    'Medical document' => Icons.document_scanner_outlined, 'Review document extractions' => Icons.fact_check_outlined, 'Appointment' => Icons.calendar_month_outlined,
    'Voice note' => Icons.mic_none, _ => Icons.medical_services_outlined,
  };
}

class CheckupForm extends StatefulWidget {
  const CheckupForm({super.key});
  @override
  State<CheckupForm> createState() => _CheckupFormState();
}
class _CheckupFormState extends State<CheckupForm> {
  final formKey = GlobalKey<FormState>();
  final provider = TextEditingController(), facility = TextEditingController(), reason = TextEditingController(), findings = TextEditingController(), followUp = TextEditingController();
  final specialty = TextEditingController(), professionalId = TextEditingController(), department = TextEditingController(), referral = TextEditingController(), tests = TextEditingController(), plan = TextEditingController();
  String visitMode = 'In person';
  DateTime? nextFollowUp;
  String type = 'Routine checkup';
  DateTime date = DateTime.now();
  List<PatientRecord> availableObservations = [];
  final Set<String> linkedObservationIds = {};
  @override
  void initState() {
    super.initState();
    patientRecords.readAll().then((items) {
      if (mounted) setState(() => availableObservations = items.where((r) => r.resourceType == 'observation').toList());
    });
  }
  @override
  void dispose() { provider.dispose(); facility.dispose(); reason.dispose(); findings.dispose(); followUp.dispose(); specialty.dispose(); professionalId.dispose(); department.dispose(); referral.dispose(); tests.dispose(); plan.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Log checkup', style: TextStyle(fontWeight: FontWeight.w800))),
    body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Record a visit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
      const SizedBox(height: 6), const Text('Capture what happened and what needs to happen next.', style: TextStyle(color: Color(0xFF69708E))),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Visit type', border: OutlineInputBorder()), items: ['Routine checkup','Consultation','Screening','Follow-up','Urgent visit','Other'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(), onChanged:(v)=>setState(()=>type=v!)),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: () async { final d=await showDatePicker(context:context, initialDate:date, firstDate:DateTime(2000), lastDate:DateTime(2100)); if(d!=null)setState(()=>date=d); }, icon: const Icon(Icons.calendar_today), label: Text('Visit date: ${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}')),
      const SizedBox(height: 14),
      _field(provider,'Clinician / provider'), const SizedBox(height: 14),
      _field(professionalId,'Professional identifier (if available)'), const SizedBox(height: 14),
      _field(specialty,'Clinician specialty'), const SizedBox(height: 14),
      _field(department,'Department'), const SizedBox(height: 14),
      _field(facility,'Facility'), const SizedBox(height: 14),
      DropdownButtonFormField<String>(value: visitMode, decoration: const InputDecoration(labelText: 'Visit mode', border: OutlineInputBorder()), items: const ['In person','Remote'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(), onChanged:(v)=>setState(()=>visitMode=v!)),
      const SizedBox(height: 14),
      _field(referral,'Referral source (optional)'), const SizedBox(height: 14),
      _field(reason,'Reason for visit',lines:3), const SizedBox(height: 14),
      _field(findings,'Findings and notes',lines:4), const SizedBox(height: 14),
      _field(tests,'Tests ordered / results (optional)',lines:3), const SizedBox(height: 14),
      _field(plan,'Plan and clinician instructions (optional)',lines:3), const SizedBox(height: 14),
      _field(followUp,'Follow-up instructions (optional)',lines:3),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: () async { final d=await showDatePicker(context:context, initialDate:nextFollowUp??date, firstDate:date, lastDate:DateTime(2100)); if(d!=null)setState(()=>nextFollowUp=d); }, icon: const Icon(Icons.event_available), label: Text(nextFollowUp==null?'Set next follow-up date':'Next follow-up: ${nextFollowUp!.year}-${nextFollowUp!.month.toString().padLeft(2,'0')}-${nextFollowUp!.day.toString().padLeft(2,'0')}')),
      if (availableObservations.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Link related vital observations', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
        const SizedBox(height: 4),
        const Text('Select any measurements recorded as part of this visit.', style: TextStyle(fontSize: 12, color: Color(0xFF69708E))),
        ...availableObservations.map((record) => CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: linkedObservationIds.contains(record.id),
          title: Text(record.payload['display']?.toString() ?? 'Vital observation'),
          subtitle: Text('${record.payload['value_quantity'] ?? record.payload['value_text'] ?? ''} ${record.payload['unit'] ?? ''} · ${record.recordedAt.toLocal().toString().split('.').first}'),
          onChanged: (checked) => setState(() {
            if (checked == true) { linkedObservationIds.add(record.id); } else { linkedObservationIds.remove(record.id); }
          }),
        )),
      ],
      const SizedBox(height: 12),
      const Text('Provenance: information entered here is patient-reported unless later authenticated by an authorized clinician.', style: TextStyle(fontSize: 12, color: Color(0xFF69708E))),
      const SizedBox(height: 24),
      FilledButton(onPressed: () async {
        if (!formKey.currentState!.validate()) return;
        try {
          final mappedType = switch (type) {
            'Routine checkup' => 'routine_checkup',
            'Follow-up' => 'follow_up',
            'Urgent visit' => 'urgent_care',
            'Consultation' => 'specialist_visit',
            _ => 'other',
          };
          await patientRecords.create(
            resourceType: 'encounter',
            recordedAt: DateTime.now().toUtc(),
            fields: {
              'encounter_type': mappedType,
              'status': 'completed',
              'started_at': date.toUtc().toIso8601String(),
              'provider_name': provider.text.trim().isEmpty ? null : provider.text.trim(),
              'provider_identifier': professionalId.text.trim().isEmpty ? null : professionalId.text.trim(),
              'provider_specialty': specialty.text.trim().isEmpty ? null : specialty.text.trim(),
              'department': department.text.trim().isEmpty ? null : department.text.trim(),
              'organization': facility.text.trim().isEmpty ? null : facility.text.trim(),
              'visit_mode': visitMode.toLowerCase().replaceAll(' ', '_'),
              'referral_source': referral.text.trim().isEmpty ? null : referral.text.trim(),
              'reason': reason.text.trim(),
              'clinical_notes': findings.text.trim().isEmpty ? null : findings.text.trim(),
              'tests_and_results': tests.text.trim().isEmpty ? null : tests.text.trim(),
              'plan_and_instructions': plan.text.trim().isEmpty ? null : plan.text.trim(),
              'follow_up_instructions': followUp.text.trim().isEmpty ? null : followUp.text.trim(),
              'next_follow_up_at': nextFollowUp?.toUtc().toIso8601String(),
              'related_observation_ids': linkedObservationIds.toList(),
            }..removeWhere((key, value) => value == null),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checkup encrypted and saved on this device.')));
          Navigator.pop(context);
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the encrypted checkup. Please try again.')));
        }
      }, child: const Padding(padding: EdgeInsets.all(14), child: Text('Save checkup securely'))),
    ])),
  );
  Widget _field(TextEditingController c,String label,{int lines=1}) => TextFormField(controller:c, maxLines:lines, decoration:InputDecoration(labelText:label, border:const OutlineInputBorder()), validator:(v)=>label=='Reason for visit' && (v==null||v.trim().isEmpty)?'Add a reason or enter “Not specified”.':null);
}


class ClinicalRecordForm extends StatefulWidget {
  const ClinicalRecordForm({super.key, required this.kind, this.existing});
  final String kind;
  final PatientRecord? existing;
  @override
  State<ClinicalRecordForm> createState() => _ClinicalRecordFormState();
}

class _ClinicalRecordFormState extends State<ClinicalRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _unit = TextEditingController();
  final _notes = TextEditingController();
  final _reaction = TextEditingController();
  final _dose = TextEditingController();
  final _frequency = TextEditingController();
  final _doseTimes = TextEditingController();
  final _route = TextEditingController();
  final _prescriber = TextEditingController();
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  final _quantity = TextEditingController();
  final _refills = TextEditingController();
  final _refillDate = TextEditingController();
  String _choice = '';
  String _status = '';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing?.payload ?? const <String, dynamic>{};
    switch (widget.kind) {
      case 'Vitals':
        _choice = (p['code'] as String?) ?? 'heart_rate';
        _name.text = (p['display'] as String?) ?? '';
        _value.text = (p['value_quantity']?.toString()) ?? '';
        _unit.text = (p['unit'] as String?) ?? '';
        _notes.text = (p['notes'] as String?) ?? '';
        break;
      case 'Medication':
        _name.text = (p['medication_name'] as String?) ?? '';
        _dose.text = (p['dose'] as String?) ?? '';
        _frequency.text = (p['frequency'] as String?) ?? '';
        _doseTimes.text = (p['dose_times'] as List?)?.join(', ') ?? '';
        _route.text = (p['route'] as String?) ?? '';
        _prescriber.text = (p['prescriber'] as String?) ?? '';
        _startDate.text = (p['start_date'] as String?) ?? '';
        _endDate.text = (p['end_date'] as String?) ?? '';
        _quantity.text = (p['quantity'] as String?) ?? '';
        _refills.text = p['refills_remaining']?.toString() ?? '';
        _refillDate.text = (p['refill_due_date'] as String?) ?? '';
        _status = (p['status'] as String?) ?? 'active';
        _notes.text = (p['notes'] as String?) ?? '';
        break;
      case 'Allergies':
        _name.text = (p['substance'] as String?) ?? '';
        _reaction.text = (p['reaction'] as String?) ?? '';
        _choice = (p['severity'] as String?) ?? 'unknown';
        _status = (p['status'] as String?) ?? 'active';
        _notes.text = (p['notes'] as String?) ?? '';
        break;
      case 'Conditions':
        _name.text = (p['display'] as String?) ?? '';
        _choice = (p['status'] as String?) ?? 'active';
        _notes.text = (p['notes'] as String?) ?? '';
        break;
    }
    if (widget.existing != null) _date = widget.existing!.recordedAt;
  }

  @override
  void dispose() {
    _name.dispose(); _value.dispose(); _unit.dispose(); _notes.dispose();
    _reaction.dispose(); _dose.dispose(); _frequency.dispose(); _doseTimes.dispose(); _route.dispose(); _prescriber.dispose(); _startDate.dispose(); _endDate.dispose(); _quantity.dispose(); _refills.dispose(); _refillDate.dispose();
    super.dispose();
  }

  String get _title => widget.existing == null ? 'Add ${widget.kind.toLowerCase()}' : 'Edit ${widget.kind.toLowerCase()}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w800))),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(_title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
      const SizedBox(height: 6),
      const Text('Information you enter is saved as patient-reported and unverified.', style: TextStyle(color: Color(0xFF69708E))),
      const SizedBox(height: 20),
      if (widget.kind == 'Vitals') ..._vitalFields(),
      if (widget.kind == 'Medication') ..._medicationFields(),
      if (widget.kind == 'Allergies') ..._allergyFields(),
      if (widget.kind == 'Conditions') ..._conditionFields(),
      const SizedBox(height: 14),
      TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Padding(padding: const EdgeInsets.all(14), child: Text(_saving ? 'Saving…' : 'Save securely')),
      ),
    ])),
  );

  List<Widget> _vitalFields() => [
    DropdownButtonFormField<String>(
      value: _choice,
      decoration: const InputDecoration(labelText: 'Measurement', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'heart_rate', child: Text('Heart rate')),
        DropdownMenuItem(value: 'blood_pressure', child: Text('Blood pressure')),
        DropdownMenuItem(value: 'blood_glucose', child: Text('Blood glucose')),
        DropdownMenuItem(value: 'body_temperature', child: Text('Body temperature')),
        DropdownMenuItem(value: 'oxygen_saturation', child: Text('Oxygen saturation')),
        DropdownMenuItem(value: 'body_weight', child: Text('Weight')),
      ],
      onChanged: (v) => setState(() => _choice = v ?? 'heart_rate'),
    ),
    const SizedBox(height: 14),
    _input(_value, 'Numeric value', keyboard: const TextInputType.numberWithOptions(decimal: true)),
    const SizedBox(height: 14),
    _input(_unit, 'Unit (e.g. bpm, mmHg, mmol/L)'),
    const SizedBox(height: 14),
    _input(_name, 'Display label (e.g. Resting heart rate)'),
  ];

  List<Widget> _medicationFields() => [
    _input(_name, 'Medication name', required: true),
    const SizedBox(height: 14),
    _input(_dose, 'Dose / strength'),
    const SizedBox(height: 14),
    _input(_frequency, 'Frequency (as prescribed)'),
    const SizedBox(height: 14),
    _input(_doseTimes, 'Exact dose times (24-hour, comma-separated; e.g. 08:00, 20:00)'),
    const SizedBox(height: 5),
    const Text('Enter exact times from the prescription or clinician. Leave blank if not specified; reminders will not be generated.', style: TextStyle(fontSize: 12, color: Color(0xFF69708E))),
    const SizedBox(height: 14),
    _input(_route, 'Route (e.g. oral, topical)'),
    const SizedBox(height: 14),
    _input(_prescriber, 'Prescriber (if known)'),
    const SizedBox(height: 14),
    _input(_startDate, 'Start date (YYYY-MM-DD)'),
    const SizedBox(height: 14),
    _input(_endDate, 'End date (YYYY-MM-DD)'),
    const SizedBox(height: 14),
    _input(_quantity, 'Quantity / pack size'),
    const SizedBox(height: 14),
    _input(_refills, 'Refills remaining', keyboard: TextInputType.number),
    const SizedBox(height: 14),
    _input(_refillDate, 'Refill due date (YYYY-MM-DD)'),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      value: _status.isEmpty ? 'active' : _status,
      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'on_hold', child: Text('On hold')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'stopped', child: Text('Stopped')),
        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ],
      onChanged: (v) => setState(() => _status = v ?? 'unknown'),
    ),
  ];

  List<Widget> _allergyFields() => [
    _input(_name, 'Allergen / substance', required: true),
    const SizedBox(height: 14),
    _input(_reaction, 'Reaction (if known)'),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      value: _choice.isEmpty ? 'unknown' : _choice,
      decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'mild', child: Text('Mild')),
        DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
        DropdownMenuItem(value: 'severe', child: Text('Severe')),
        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ],
      onChanged: (v) => setState(() => _choice = v ?? 'unknown'),
    ),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      value: _status.isEmpty ? 'active' : _status,
      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ],
      onChanged: (v) => setState(() => _status = v ?? 'unknown'),
    ),
  ];

  List<Widget> _conditionFields() => [
    _input(_name, 'Condition name', required: true),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      value: _choice.isEmpty ? 'active' : _choice,
      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'active', child: Text('Active')),
        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        DropdownMenuItem(value: 'in_remission', child: Text('In remission')),
        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ],
      onChanged: (v) => setState(() => _choice = v ?? 'unknown'),
    ),
  ];

  Widget _input(TextEditingController controller, String label, {bool required = false, TextInputType? keyboard}) =>
    TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (v) => v == null || v.trim().isEmpty ? 'This field is required' : null : null,
    );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.kind == 'Medication') {
      DateTime? parseDate(String raw, String label) {
        if (raw.trim().isEmpty) return null;
        final parsed = DateTime.tryParse(raw.trim());
        if (parsed == null || raw.trim().length != 10) {
          throw FormatException('$label must use YYYY-MM-DD.');
        }
        return parsed;
      }
      try {
        final start = parseDate(_startDate.text, 'Start date');
        final end = parseDate(_endDate.text, 'End date');
        parseDate(_refillDate.text, 'Refill due date');
        if (start != null && end != null && end.isBefore(start)) {
          throw const FormatException('End date cannot be before start date.');
        }
        final doseTimes = _doseTimes.text.trim().isEmpty ? <String>[] : _doseTimes.text.split(',').map((v)=>v.trim()).toList();
        for (final time in doseTimes) {
          if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
            throw const FormatException('Dose times must use 24-hour HH:MM format, separated by commas.');
          }
        }
        if (doseTimes.toSet().length != doseTimes.length) {
          throw const FormatException('Remove duplicate dose times.');
        }
        if (_refills.text.trim().isNotEmpty && int.tryParse(_refills.text.trim()) == null) {
          throw const FormatException('Refills remaining must be a whole number.');
        }
      } on FormatException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> fields;
      final String resourceType;
      switch (widget.kind) {
        case 'Vitals':
          final number = double.tryParse(_value.text.trim());
          if (number == null || !number.isFinite) {
            throw const FormatException('Enter a valid numeric measurement');
          }
          resourceType = 'observation';
          fields = {
            'code': _choice,
            'display': _name.text.trim().isEmpty ? _choice.replaceAll('_', ' ') : _name.text.trim(),
            'status': 'final',
            'effective_at': _date.toUtc().toIso8601String(),
            'value_quantity': number,
            'unit': _unit.text.trim(),
            'components': <String, dynamic>{},
            'notes': _notes.text.trim(),
          };
          break;
        case 'Medication':
          resourceType = 'medication_statement';
          fields = {
            'medication_name': _name.text.trim(),
            'dose': _dose.text.trim(),
            'frequency': _frequency.text.trim(),
            'dose_times': _doseTimes.text.trim().isEmpty ? <String>[] : _doseTimes.text.split(',').map((v)=>v.trim()).toList(),
            'route': _route.text.trim(),
            'prescriber': _prescriber.text.trim(),
            if (_startDate.text.trim().isNotEmpty) 'start_date': _startDate.text.trim(),
            if (_endDate.text.trim().isNotEmpty) 'end_date': _endDate.text.trim(),
            if (_quantity.text.trim().isNotEmpty) 'quantity': _quantity.text.trim(),
            if (_refills.text.trim().isNotEmpty) 'refills_remaining': int.tryParse(_refills.text.trim()),
            if (_refillDate.text.trim().isNotEmpty) 'refill_due_date': _refillDate.text.trim(),
            'status': _status.isEmpty ? 'active' : _status,
            'notes': _notes.text.trim(),
          };
          break;
        case 'Allergies':
          resourceType = 'allergy';
          fields = {
            'substance': _name.text.trim(),
            'reaction': _reaction.text.trim(),
            'severity': _choice.isEmpty ? 'unknown' : _choice,
            'status': _status.isEmpty ? 'active' : _status,
            'notes': _notes.text.trim(),
          };
          break;
        default:
          resourceType = 'condition';
          fields = {
            'display': _name.text.trim(),
            'status': _choice.isEmpty ? 'active' : _choice,
            'notes': _notes.text.trim(),
          };
      }
      fields.removeWhere((key, value) => value is String && value.trim().isEmpty);
      PatientRecord? savedMedication;
      if (widget.existing == null) {
        final created = await patientRecords.create(resourceType: resourceType, fields: fields);
        if (resourceType == 'medication_statement') savedMedication = created;
      } else {
        final updated = await patientRecords.update(widget.existing!, fields: fields);
        if (resourceType == 'medication_statement') savedMedication = updated;
      }
      if (savedMedication != null) {
        final times = (fields['dose_times'] as List?)?.map((e)=>e.toString()).toList() ?? <String>[];
        final startRaw = fields['start_date']?.toString();
        final endRaw = fields['end_date']?.toString();
        await HealthNotificationCenter.instance.scheduleMedication(
          medicationId: savedMedication.id,
          medicationName: fields['medication_name'].toString(),
          prescribedDose: fields['dose'].toString(),
          times: fields['status'] == 'active' ? times : <String>[],
          startDate: startRaw == null ? null : DateTime.tryParse(startRaw),
          endDate: endRaw == null ? null : DateTime.tryParse(endRaw),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record encrypted and saved on this device.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is FormatException ? error.message : 'Could not save this record securely.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}



class MedicationManagementPage extends StatefulWidget {
  const MedicationManagementPage({super.key});
  @override
  State<MedicationManagementPage> createState() => _MedicationManagementPageState();
}

class _MedicationManagementPageState extends State<MedicationManagementPage> {
  static const ink = Color(0xFF171B3D);
  static const muted = Color(0xFF69708E);
  late Future<List<PatientRecord>> _future;
  @override
  void initState() { super.initState(); _future = _loadAndReconcileSchedules(); }

  Future<List<PatientRecord>> _loadAndReconcileSchedules() async {
    final all = await patientRecords.readAll();
    final adherence = MedicationAdherenceEngine.analyze(all);
    for (final dose in adherence.doses.where((d)=>d.state==DoseState.overdue)) {
      final stamp='${dose.dueAt.year}${dose.dueAt.month.toString().padLeft(2,'0')}${dose.dueAt.day.toString().padLeft(2,'0')}-${dose.dueAt.hour.toString().padLeft(2,'0')}${dose.dueAt.minute.toString().padLeft(2,'0')}';
      await HealthNotificationCenter.instance.addInternalOnce(
        id:'dose-overdue-${dose.medicationId}-$stamp',
        title:'Medication dose needs attention',
        body:'${dose.medicationName} · ${dose.dose} was scheduled for ${dose.dueAt.hour.toString().padLeft(2,'0')}:${dose.dueAt.minute.toString().padLeft(2,'0')}. Confirm whether it was taken, missed or skipped.',
        kind:HealthNoticeKind.warning,
      );
    }
    for (final medication in all.where((r) => r.resourceType == 'medication_statement')) {
      final p = medication.payload;
      final times = (p['dose_times'] as List?)?.map((e)=>e.toString()).toList() ?? <String>[];
      final active = p['status'] == 'active';
      await HealthNotificationCenter.instance.scheduleMedication(
        medicationId: medication.id,
        medicationName: (p['medication_name'] ?? 'Medication').toString(),
        prescribedDose: (p['dose'] ?? 'See prescription').toString(),
        times: active ? times : <String>[],
        startDate: DateTime.tryParse((p['start_date'] ?? '').toString()),
        endDate: DateTime.tryParse((p['end_date'] ?? '').toString()),
      );
    }
    return all;
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadAndReconcileSchedules());
    await _future;
  }

  Future<void> _log(PatientRecord medication, String event) async {
    try {
      await patientRecords.create(
        resourceType: 'medication_dose_log',
        fields: {
          'medication_record_id': medication.id,
          'event_type': event,
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dose event recorded: ${event.replaceAll('_', ' ')}.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the medication event.')));
    }
  }

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.length >= 10) return raw.substring(0, 10);
    return 'Not recorded';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Medication management')),
    body: FutureBuilder<List<PatientRecord>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('Could not read encrypted medication records.'));
        final all = snapshot.data ?? const <PatientRecord>[];
        final medications = all.where((r) => r.resourceType == 'medication_statement').toList()
          ..sort((a, b) => (a.payload['medication_name'] ?? '').toString().compareTo((b.payload['medication_name'] ?? '').toString()));
        final logs = all.where((r) => r.resourceType == 'medication_dose_log').toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [Color(0xFFF2EAFE), Color(0xFFE7E1FF)]),
                ),
                child: Row(children: [
                  const Icon(Icons.medication_outlined, size: 42, color: Color(0xFF7938DB)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Medication tracker', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Text(
                        '${medications.where((m) => m.payload['status'] == 'active').length} active · ${logs.length} dose events recorded',
                        key: ValueKey('${medications.length}-${logs.length}'),
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Text('Your medications', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink))),
                TextButton.icon(onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClinicalRecordForm(kind: 'Medication')));
                  await _refresh();
                }, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
              ]),
              if (medications.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECECF4))),
                  child: const Column(children: [
                    Icon(Icons.medication_outlined, size: 38, color: Color(0xFF7938DB)),
                    SizedBox(height: 8),
                    Text('No medication records yet', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
                    Text('Add a medication to start recording its schedule and dose events.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                  ]),
                )
              else ...medications.map((med) {
                final p = med.payload;
                final medLogs = logs.where((l) => l.payload['medication_record_id'] == med.id).toList()
                  ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
                final active = p['status'] == 'active';
                final refillRaw = p['refill_due_date'];
                final refill = DateTime.tryParse((refillRaw ?? '').toString());
                final isRefillDue = refill != null && !refill.isAfter(DateTime.now().add(const Duration(days: 7)));
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECECF4))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.medication_outlined, color: Color(0xFF7938DB)),
                      const SizedBox(width: 8),
                      Expanded(child: Text((p['medication_name'] ?? 'Medication').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: active ? const Color(0xFFE9F6EF) : const Color(0xFFF1F0F5), borderRadius: BorderRadius.circular(20)), child: Text((p['status'] ?? 'unknown').toString().replaceAll('_', ' '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 8),
                    Text([p['dose'], p['route'], p['frequency']].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · '), style: const TextStyle(color: muted)),
                    if ((p['dose_times'] as List?)?.isNotEmpty == true)
                      Padding(padding: const EdgeInsets.only(top:5), child: Wrap(spacing:6,runSpacing:5,children:[
                        const Icon(Icons.schedule,size:15,color:Color(0xFF7938DB)),
                        ...((p['dose_times'] as List).map((t)=>Container(
                          padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                          decoration:BoxDecoration(color:const Color(0xFFF2EAFE),borderRadius:BorderRadius.circular(12)),
                          child:Text(t.toString(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:Color(0xFF7938DB)))))),
                      ])),
                    if (p['prescriber'] != null) Text('Prescriber: ${p['prescriber']}', style: const TextStyle(fontSize: 12, color: muted)),
                    if (p['start_date'] != null || p['end_date'] != null) Text('Period: ${_date(p['start_date'])} → ${_date(p['end_date'])}', style: const TextStyle(fontSize: 12, color: muted)),
                    if (p['quantity'] != null || p['refills_remaining'] != null) Text('Quantity: ${p['quantity'] ?? '—'} · Refills remaining: ${p['refills_remaining'] ?? '—'}', style: const TextStyle(fontSize: 12, color: muted)),
                    if (refill != null) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                      Icon(Icons.event_repeat, size: 15, color: isRefillDue ? const Color(0xFFB36A17) : muted),
                      const SizedBox(width: 5),
                      Text('Refill due ${_date(refillRaw)}${isRefillDue ? ' · approaching / overdue' : ''}', style: TextStyle(fontSize: 12, color: isRefillDue ? const Color(0xFFB36A17) : muted)),
                    ])),
                    const Divider(height: 22),
                    Row(children: [
                      Expanded(child: Text('${medLogs.length} dose events', style: const TextStyle(fontWeight: FontWeight.w700, color: ink))),
                      TextButton(onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ClinicalRecordForm(kind: 'Medication', existing: med)));
                        await _refresh();
                      }, child: const Text('Edit')),
                    ]),
                    if (medLogs.isNotEmpty)
                      Text('Latest: ${medLogs.first.payload['event_type']} · ${medLogs.first.recordedAt.toLocal().toString().split('.').first}', style: const TextStyle(fontSize: 12, color: muted)),
                    if (active) Wrap(spacing: 4, children: [
                      TextButton.icon(onPressed: () => _log(med, 'taken'), icon: const Icon(Icons.check_circle_outline, size: 17), label: const Text('Taken')),
                      TextButton.icon(onPressed: () => _log(med, 'missed'), icon: const Icon(Icons.schedule, size: 17), label: const Text('Missed')),
                      TextButton.icon(onPressed: () => _log(med, 'skipped'), icon: const Icon(Icons.remove_circle_outline, size: 17), label: const Text('Skipped')),
                    ]),
                    const Text('Dose events are patient-reported and do not verify ingestion.', style: TextStyle(fontSize: 10, color: muted)),
                  ]),
                );
              }),
              const SizedBox(height: 12),
              const Text('No interaction checking is performed. Confirm medication combinations, dosing and changes with a qualified pharmacist or clinician.', style: TextStyle(fontSize: 11, color: muted, height: 1.4)),
            ],
          ),
        );
      },
    ),
  );
}



class CrossDomainHealthPanel extends StatefulWidget {
  const CrossDomainHealthPanel({super.key});
  @override State<CrossDomainHealthPanel> createState()=>_CrossDomainHealthPanelState();
}
class _CrossDomainHealthPanelState extends State<CrossDomainHealthPanel>{
  late Future<(CrossDomainSnapshot,List<PatientRecord>)> _future;
  @override void initState(){super.initState();_future=_load();}
  Future<(CrossDomainSnapshot,List<PatientRecord>)> _load()async{
    final records=await patientRecords.readAll();
    return (CrossDomainHealthIntelligence.analyze(records),records);
  }
  String _date(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  Future<void> _showRelationship(HealthRelationship relationship,List<PatientRecord> records)async{
    final related=records.where((r)=>relationship.sourceRecordIds.contains(r.id)).toList();
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
      builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(relationship.title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
        const SizedBox(height:8),
        Text(relationship.description,style:const TextStyle(color:Color(0xFF69708E),height:1.4)),
        const SizedBox(height:14),
        const Text('Source records',style:TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
        const SizedBox(height:7),
        ...related.map((r){
          final label=switch(r.resourceType){
            'symptom_entry'=>'Symptom: ${r.payload['symptom_name']??'—'}',
            'observation'=>'Measurement: ${r.payload['display']??r.payload['code']??'—'}',
            'medication_dose_log'=>'Dose event: ${r.payload['event_type']??'—'}',
            'encounter'=>'Visit: ${r.payload['reason']??r.payload['encounter_type']??'—'}',
            'document_reference'=>'Document: ${r.payload['title']??'—'}',
            'health_journal'=>'Journal entry',
            _=>r.resourceType,
          };
          return ListTile(contentPadding:EdgeInsets.zero,dense:true,leading:const Icon(Icons.lock_outline,color:Color(0xFF7938DB)),
            title:Text(label,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
            subtitle:Text('${r.resourceType} · ${_date(r.recordedAt.toLocal())} · patient/imported record',style:const TextStyle(fontSize:11,color:Color(0xFF69708E))));
        }),
        const SizedBox(height:8),
        const Text('These records are shown together because their recorded dates overlap. This does not establish causation.',style:TextStyle(fontSize:11,color:Color(0xFF69708E))),
        Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))),
      ]))));
  }
  @override Widget build(BuildContext context)=>FutureBuilder<(CrossDomainSnapshot,List<PatientRecord>)>(
    future:_future,builder:(context,snapshot){
      if(!snapshot.hasData)return const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator()));
      final data=snapshot.data!.$1;final records=snapshot.data!.$2;
      return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFECECF4))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Icon(Icons.hub_outlined,color:Color(0xFF7938DB),size:26),const SizedBox(width:9),const Expanded(child:Text('Cross-domain relationships',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))))]),
          const SizedBox(height:5),
          const Text('Records that occurred near one another in time. These are review prompts, not medical conclusions.',style:TextStyle(fontSize:11,color:Color(0xFF69708E))),
          const SizedBox(height:14),
          Wrap(spacing:14,runSpacing:10,children:[
            _miniMetric('Symptoms','${data.symptomEpisodesCompared}'),
            _miniMetric('Measurements','${data.observationsCompared}'),
            _miniMetric('Dose events','${data.medicationEventsCompared}'),
            _miniMetric('Visits','${data.encountersCompared}'),
            _miniMetric('Documents','${data.documentsCompared}'),
          ]),
          const Divider(height:24),
          if(data.relationships.isEmpty)
            const Padding(padding:EdgeInsets.symmetric(vertical:10),child:Text('Not enough overlapping dated records to show relationships yet. Add symptom episodes, measurements, dose events, visits or documents to build a richer timeline.',style:TextStyle(fontSize:12,color:Color(0xFF69708E),height:1.4)))
          else ...[
            Text('${data.relationships.length} temporal overlap(s) found',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
            const SizedBox(height:8),
            ...data.relationships.take(8).map((r)=>InkWell(
              borderRadius:BorderRadius.circular(12),
              onTap:()=>_showRelationship(r,records),
              child:Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Container(width:34,height:34,decoration:BoxDecoration(color:const Color(0xFFF0EAFE),borderRadius:BorderRadius.circular(10)),child:Icon(switch(r.kind){
                  'symptom_observation'=>Icons.monitor_heart_outlined,
                  'symptom_medication'=>Icons.medication_outlined,
                  'symptom_journal'=>Icons.edit_note,
                  'symptom_encounter'||'encounter_observation'=>Icons.medical_services_outlined,
                  _=>Icons.description_outlined,
                },color:const Color(0xFF7938DB),size:19)),
                const SizedBox(width:10),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(r.title,style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF171B3D),fontSize:13)),
                  const SizedBox(height:3),
                  Text(r.description,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Color(0xFF69708E),height:1.35)),
                  const SizedBox(height:3),
                  Text('${_date(r.firstAt.toLocal())} · ${r.eventCount} source records',style:const TextStyle(fontSize:10,color:Color(0xFF8A8FA7))),
                ])),
                const Icon(Icons.chevron_right,color:Color(0xFF8A8FA7)),
              ])),
            )),
          ],
          const Divider(height:20),
          ...data.notes.map((n)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Icon(Icons.info_outline,size:14,color:Color(0xFF8A8FA7)),const SizedBox(width:6),Expanded(child:Text(n,style:const TextStyle(fontSize:10,color:Color(0xFF69708E),height:1.35)))
          ]))),
        ]),
      );
    },
  );
}

class SymptomEntryForm extends StatefulWidget {
  const SymptomEntryForm({super.key});
  @override State<SymptomEntryForm> createState()=>_SymptomEntryFormState();
}
class _SymptomEntryFormState extends State<SymptomEntryForm> {
  final _name=TextEditingController(),_duration=TextEditingController(),_triggers=TextEditingController(),_notes=TextEditingController();
  String _area='general';
  int _severity=5;
  DateTime _occurred=DateTime.now();
  bool _saving=false;
  @override void dispose(){_name.dispose();_duration.dispose();_triggers.dispose();_notes.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Log a symptom')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('Record what you experienced',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
      const SizedBox(height:6),
      const Text('Your entries help you review your own symptom history. They do not provide a diagnosis.',style:TextStyle(color:Color(0xFF69708E))),
      const SizedBox(height:20),
      TextField(controller:_name,decoration:const InputDecoration(labelText:'Symptom (e.g. headache, nausea)',border:OutlineInputBorder())),
      const SizedBox(height:14),
      DropdownButtonFormField<String>(value:_area,decoration:const InputDecoration(labelText:'Body area / system',border:OutlineInputBorder()),
        items:const [
          ('general','General'),('head','Head'),('chest','Chest'),('abdomen','Abdomen'),('back','Back'),('muscles','Muscles'),('joints','Joints'),('skin','Skin'),('breathing','Breathing'),('digestive','Digestive'),('other','Other')
        ].map((e)=>DropdownMenuItem(value:e.$1,child:Text(e.$2))).toList(),onChanged:(v)=>setState(()=>_area=v??'general')),
      const SizedBox(height:18),
      Row(children:[const Expanded(child:Text('Severity',style:TextStyle(fontWeight:FontWeight.w700))),Text('$_severity / 10',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF7938DB)))]),
      Slider(value:_severity.toDouble(),min:1,max:10,divisions:9,label:'$_severity',onChanged:(v)=>setState(()=>_severity=v.round())),
      OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:_occurred,firstDate:DateTime(2000),lastDate:DateTime.now());if(d!=null)setState(()=>_occurred=d);},icon:const Icon(Icons.calendar_today),label:Text('Date: ${_occurred.year}-${_occurred.month.toString().padLeft(2,'0')}-${_occurred.day.toString().padLeft(2,'0')}')),
      const SizedBox(height:14),
      TextField(controller:_duration,decoration:const InputDecoration(labelText:'Duration (optional)',hintText:'e.g. 30 minutes, intermittent',border:OutlineInputBorder())),
      const SizedBox(height:14),
      TextField(controller:_triggers,decoration:const InputDecoration(labelText:'Possible triggers (optional)',hintText:'Separate with commas',border:OutlineInputBorder())),
      const SizedBox(height:14),
      TextField(controller:_notes,maxLines:4,decoration:const InputDecoration(labelText:'Additional notes (optional)',border:OutlineInputBorder())),
      const SizedBox(height:12),
      const Text('Possible triggers are your own observations, not confirmed causes.',style:TextStyle(fontSize:12,color:Color(0xFF69708E))),
      const SizedBox(height:20),
      FilledButton.icon(onPressed:_saving?null:()async{
        if(_name.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a symptom name.')));return;}
        setState(()=>_saving=true);
        try{
          await patientRecords.create(resourceType:'symptom_entry',recordedAt:_occurred.toUtc(),fields:{
            'symptom_name':_name.text.trim(),'body_area':_area,'severity':_severity,'occurred_at':_occurred.toUtc().toIso8601String(),
            if(_duration.text.trim().isNotEmpty)'duration':_duration.text.trim(),
            'possible_triggers':_triggers.text.split(',').map((v)=>v.trim()).where((v)=>v.isNotEmpty).toList(),
            if(_notes.text.trim().isNotEmpty)'notes':_notes.text.trim(),
          });
          if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Symptom episode saved to your encrypted record.')));Navigator.pop(context);}
        }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not save this symptom entry.')));}
        finally{if(mounted)setState(()=>_saving=false);}
      },icon:const Icon(Icons.save_outlined),label:Text(_saving?'Saving…':'Save symptom episode')),
    ]),
  );
}

class HealthJournalForm extends StatefulWidget {
  const HealthJournalForm({super.key});
  @override State<HealthJournalForm> createState()=>_HealthJournalFormState();
}
class _HealthJournalFormState extends State<HealthJournalForm>{
  final _entry=TextEditingController();
  int _mood=3,_energy=3,_stress=3;
  bool _saving=false;
  @override void dispose(){_entry.dispose();super.dispose();}
  Widget _rating(String title,int value,ValueChanged<int> onChanged)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.w700))),Text('$value / 5',style:const TextStyle(color:Color(0xFF7938DB),fontWeight:FontWeight.w800))]),
    Slider(value:value.toDouble(),min:1,max:5,divisions:4,onChanged:(v)=>onChanged(v.round())),
  ]);
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Health journal')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('A little context matters',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
      const SizedBox(height:6),
      const Text('Capture how you are feeling and anything you want to remember about your day.',style:TextStyle(color:Color(0xFF69708E))),
      const SizedBox(height:20),
      _rating('Mood',_mood,(v)=>setState(()=>_mood=v)),
      _rating('Energy',_energy,(v)=>setState(()=>_energy=v)),
      _rating('Stress',_stress,(v)=>setState(()=>_stress=v)),
      const SizedBox(height:8),
      TextField(controller:_entry,minLines:5,maxLines:10,decoration:const InputDecoration(labelText:'Journal entry',hintText:'What did you notice today?',alignLabelWithHint:true,border:OutlineInputBorder())),
      const SizedBox(height:8),
      const Text('Scores are personal self-ratings (1–5), not clinical scales.',style:TextStyle(fontSize:12,color:Color(0xFF69708E))),
      const SizedBox(height:20),
      FilledButton.icon(onPressed:_saving?null:()async{
        if(_entry.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Write a short journal entry first.')));return;}
        setState(()=>_saving=true);
        try{
          await patientRecords.create(resourceType:'health_journal',recordedAt:DateTime.now().toUtc(),fields:{
            'entry_text':_entry.text.trim(),'mood_score':_mood,'energy_score':_energy,'stress_score':_stress,
          });
          if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Journal entry saved securely.')));Navigator.pop(context);}
        }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not save journal entry.')));}
        finally{if(mounted)setState(()=>_saving=false);}
      },icon:const Icon(Icons.save_outlined),label:Text(_saving?'Saving…':'Save journal entry')),
    ]),
  );
}

class SymptomJournalInsightsPanel extends StatefulWidget {
  const SymptomJournalInsightsPanel({super.key});
  @override State<SymptomJournalInsightsPanel> createState()=>_SymptomJournalInsightsPanelState();
}
class _SymptomJournalInsightsPanelState extends State<SymptomJournalInsightsPanel>{
  late Future<SymptomJournalSnapshot> _future;
  @override void initState(){super.initState();_future=_load();}
  Future<SymptomJournalSnapshot> _load()async=>SymptomJournalIntelligence.analyze(await patientRecords.readAll());
  @override Widget build(BuildContext context)=>FutureBuilder<SymptomJournalSnapshot>(
    future:_future,builder:(context,snapshot){
      if(!snapshot.hasData)return const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator()));
      final data=snapshot.data!;
      String score(double? v)=>v==null?'—':'${v.toStringAsFixed(1)} / 5';
      return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFECECF4))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[const Icon(Icons.timeline,color:Color(0xFF7938DB),size:26),const SizedBox(width:9),const Expanded(child:Text('Symptom & journal patterns',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))))]),
          const SizedBox(height:10),
          Row(children:[
            Expanded(child:_miniMetric('Symptom types','${data.patterns.length}')),
            Expanded(child:_miniMetric('Episodes','${data.patterns.fold<int>(0,(sum,p)=>sum+p.episodes)}')),
            Expanded(child:_miniMetric('Journal entries','${data.journalEntries}')),
          ]),
          const Divider(height:24),
          const Text('Recorded symptom patterns',style:TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
          const SizedBox(height:8),
          if(data.patterns.isEmpty)const Text('No symptom episodes recorded yet.',style:TextStyle(color:Color(0xFF69708E),fontSize:12)),
          ...data.patterns.take(5).map((p)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF171B3D)))),Text('${p.episodes} ${p.episodes==1?'episode':'episodes'}',style:const TextStyle(fontSize:11,color:Color(0xFF69708E)))]),
            const SizedBox(height:3),
            Text('Average self-rated severity ${p.averageSeverity.toStringAsFixed(1)}/10 · highest ${p.highestSeverity}/10 · latest ${p.latestAt.toLocal().toString().split(' ').first}',style:const TextStyle(fontSize:11,color:Color(0xFF69708E))),
            if(p.commonTriggers.isNotEmpty)Text('Commonly noted possible triggers: ${p.commonTriggers.take(3).map((e)=>e).join(', ')}',style:const TextStyle(fontSize:11,color:Color(0xFF69708E))),
          ]))),
          const Divider(height:22),
          const Text('Journal self-ratings',style:TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
          const SizedBox(height:7),
          Row(children:[
            Expanded(child:_miniMetric('Mood',score(data.averageMood))),
            Expanded(child:_miniMetric('Energy',score(data.averageEnergy))),
            Expanded(child:_miniMetric('Stress',score(data.averageStress))),
          ]),
          const SizedBox(height:10),
          const Text('Descriptive summaries of patient-entered information only. These patterns do not establish a cause, diagnosis or medical risk.',style:TextStyle(fontSize:11,color:Color(0xFF69708E),height:1.4)),
        ]),
      );
    },
  );
}
Widget _miniMetric(String label,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(label,style:const TextStyle(fontSize:10,color:Color(0xFF69708E))),
  const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:Color(0xFF171B3D))),
]);

class DocumentCaptureForm extends StatefulWidget {
  const DocumentCaptureForm({super.key});
  @override
  State<DocumentCaptureForm> createState() => _DocumentCaptureFormState();
}

class _DocumentCaptureFormState extends State<DocumentCaptureForm> {
  final _title = TextEditingController();
  final _organization = TextEditingController();
  String _type = 'lab_report';
  DateTime _date = DateTime.now();
  PlatformFile? _selected;
  bool _saving = false;
  bool _extracting = false;
  String? _extractedText;
  String? _extractionMessage;
  DocumentUnderstanding? _understanding;
  List<StructuredDocumentCandidate> _acceptedCandidates = [];

  @override
  void dispose() { _title.dispose(); _organization.dispose(); super.dispose(); }

  String _mediaType(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the selected file.')));
      return;
    }
    if (file.size > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a document smaller than 20 MB.')));
      return;
    }
    setState(() { _selected = file; _extractedText = null; _extractionMessage = null; _understanding = null; _acceptedCandidates = []; if (_title.text.trim().isEmpty) _title.text = file.name; });
  }


  Future<void> _extractText() async {
    final file=_selected;
    if(file?.bytes==null)return;
    final ext=file!.name.toLowerCase().split('.').last;
    setState(()=>_extracting=true);
    try{
      final extraction=ext=='pdf'
        ? await documentTextExtractor.extractPdf(file.bytes!)
        : await documentTextExtractor.extractImagePages(file.bytes!,ext);
      final text=extraction.text;
      final understanding=DocumentUnderstandingEngine.analyze(text);
      if(!mounted)return;
      setState(()=>_extractionMessage=text.isEmpty?'No readable text was detected.': 'Processed ${extraction.pages.length} page(s) locally. Review every extracted candidate before accepting it.');
      if(text.isEmpty){setState(()=>_extractedText='');return;}
      var selectedCandidates=<StructuredDocumentCandidate>[];
      final accepted=await showDialog<bool>(context:context,barrierDismissible:false,builder:(ctx){
        final selected=List<bool>.filled(understanding.structuredCandidates.length,true);
        return StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
          title:const Text('Review document understanding'),
          content:SizedBox(width:double.maxFinite,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Suggested type: ${understanding.suggestedType.replaceAll('_',' ')} · ${(understanding.typeConfidence*100).round()}% heuristic score',style:const TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:10),
            const Text('Extracted text',style:TextStyle(fontWeight:FontWeight.w800)),
            const SizedBox(height:5),
            SelectableText(text,style:const TextStyle(fontSize:11)),
            const Divider(height:24),
            Text('Structured field candidates (${understanding.structuredCandidates.length})',style:const TextStyle(fontWeight:FontWeight.w800)),
            const Text('Select only items you believe were read correctly. These remain unverified document annotations and will not create clinical records.',style:TextStyle(fontSize:11)),
             ...List.generate(understanding.structuredCandidates.length,(i){
              final c=understanding.structuredCandidates[i];
              return CheckboxListTile(value:selected[i],contentPadding:EdgeInsets.zero,dense:true,
                title:Text('${c.kind.replaceAll('_',' ')}: ${c.fields.values.join(' · ')}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
                subtitle:Text('Page ${c.page} · ${(c.heuristicConfidence*100).round()}% heuristic · ${c.evidence}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10)),
                onChanged:(v)=>setDialog(()=>selected[i]=v??false));
            }),
            ...understanding.notes.map((n)=>Padding(padding:const EdgeInsets.only(top:5),child:Text('• $n',style:const TextStyle(fontSize:10,color:Color(0xFF69708E))))),
          ]))),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Discard extraction')),
            FilledButton(onPressed:(){selectedCandidates=List.generate(understanding.structuredCandidates.length,(i)=>i).where((i)=>selected[i]).map((i)=>understanding.structuredCandidates[i]).toList();Navigator.pop(ctx,true);},child:const Text('Accept selected')),
          ],
        ));
      });
      if(!mounted)return;
      if(accepted==true){
        setState((){
          _extractedText=text;
          _understanding=understanding;
          _acceptedCandidates=selectedCandidates;
        });
      }else{
        setState(()=>_extractedText=null);
      }
    }catch(_){
      if(mounted)setState(()=>_extractionMessage='Document processing failed on this device. The original file can still be encrypted and saved.');
    }finally{if(mounted)setState(()=>_extracting=false);}
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _selected?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a file and provide a document title.')));
      return;
    }
    setState(() => _saving = true);
    String? blobId;
    try {
      blobId = await encryptedDocuments.save(_selected!.bytes!);
      await patientRecords.create(
        resourceType: 'document_reference',
        recordedAt: DateTime.now().toUtc(),
        fields: {
          'document_type': _type,
          'title': _title.text.trim(),
          'media_type': _mediaType(_selected!.name),
          'encrypted_blob_id': blobId,
          'document_date': _date.toIso8601String().split('T').first,
          'extraction_status': _extractedText == null ? 'not_run' : (_extractedText!.isEmpty ? 'no_text_detected' : 'ocr_reviewed_by_patient'),
          if (_extractedText != null && _extractedText!.isNotEmpty) 'extracted_text': _extractedText,
          if (_understanding != null) 'suggested_document_type': _understanding!.suggestedType,
          if (_understanding != null) 'document_type_suggestion_score': _understanding!.typeConfidence,
          if (_understanding != null) 'extraction_candidate_count': _understanding!.structuredCandidates.length,
          if (_acceptedCandidates.isNotEmpty) 'accepted_document_annotations': _acceptedCandidates.map((c)=>{'kind':c.kind,'fields':c.fields,'evidence':c.evidence,'page':c.page,'heuristic_confidence':c.heuristicConfidence,'status':'patient_accepted_unverified'}).toList(),
          if (_organization.text.trim().isNotEmpty) 'issuing_organization': _organization.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document encrypted and saved on this device.')));
      Navigator.pop(context);
    } catch (_) {
      if (blobId != null) await encryptedDocuments.delete(blobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not encrypt and save this document.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add medical document')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Keep a copy of your medical documents', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
      const SizedBox(height: 6),
      const Text('Files are encrypted before being written to this device. Maximum file size: 20 MB. Image OCR runs locally; extracted text and any accepted annotations are saved encrypted and remain unverified.', style: TextStyle(color: Color(0xFF69708E))),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.attach_file), label: Text(_selected?.name ?? 'Choose PDF or image')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _selected == null || _extracting ? null : _extractText,
        icon: _extracting
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.document_scanner_outlined),
        label: Text(_extracting ? 'Reading image…' : 'Extract text / scan PDF'),
      ),
      if (_extractionMessage != null) Padding(
        padding: const EdgeInsets.only(top: 7, bottom: 8),
        child: Text(_extractionMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFF69708E))),
      ),
      if (_extractedText != null && _extractedText!.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF0EAFE), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.text_snippet_outlined, color: Color(0xFF7938DB)),
            const SizedBox(width: 8),
            Expanded(child: Text('${_extractedText!.length} characters extracted · saved encrypted with document metadata', style: const TextStyle(fontSize: 12))),
          ]),
        ),
      const SizedBox(height: 14),
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Document title', border: OutlineInputBorder())),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _type,
        decoration: const InputDecoration(labelText: 'Document type', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'lab_report', child: Text('Lab report')),
          DropdownMenuItem(value: 'prescription', child: Text('Prescription')),
          DropdownMenuItem(value: 'discharge_summary', child: Text('Discharge summary')),
          DropdownMenuItem(value: 'imaging_report', child: Text('Imaging report')),
          DropdownMenuItem(value: 'referral', child: Text('Referral')),
          DropdownMenuItem(value: 'vaccination_record', child: Text('Vaccination record')),
          DropdownMenuItem(value: 'insurance', child: Text('Insurance')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) => setState(() => _type = v ?? 'other'),
      ),
      const SizedBox(height: 14),
      TextField(controller: _organization, decoration: const InputDecoration(labelText: 'Issuing facility / organization (optional)', border: OutlineInputBorder())),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(1900), lastDate: DateTime(2100));
          if (d != null) setState(() => _date = d);
        },
        icon: const Icon(Icons.calendar_today),
        label: Text('Document date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: _saving ? null : _save, child: Padding(padding: const EdgeInsets.all(14), child: Text(_saving ? 'Encrypting…' : 'Encrypt and save'))),
    ]),
  );
}

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});
  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final _preferred = TextEditingController();
  final _legal = TextEditingController();
  final _phone = TextEditingController();
  final _contact = TextEditingController();
  final _relationship = TextEditingController();
  final _height = TextEditingController();
  DateTime? _dob;
  String _blood = 'not_recorded';
  String _sex = 'not_recorded';
  PatientRecord? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() {
    _preferred.dispose(); _legal.dispose(); _phone.dispose();
    _contact.dispose(); _relationship.dispose(); _height.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await patientRecords.readAll();
      final matches = all.where((r) => r.resourceType == 'patient_profile').toList();
      if (matches.isNotEmpty) {
        _existing = matches.first;
        final p = _existing!.payload;
        _preferred.text = (p['preferred_name'] as String?) ?? '';
        _legal.text = (p['legal_name'] as String?) ?? '';
        _phone.text = (p['emergency_contact_phone'] as String?) ?? '';
        _contact.text = (p['emergency_contact_name'] as String?) ?? '';
        _relationship.text = (p['emergency_contact_relationship'] as String?) ?? '';
        _height.text = p['height_cm']?.toString() ?? '';
        _blood = (p['blood_group'] as String?) ?? 'not_recorded';
        _sex = (p['sex_at_birth'] as String?) ?? 'not_recorded';
        final dob = p['date_of_birth'] as String?;
        if (dob != null) _dob = DateTime.tryParse(dob);
      }
    } catch (_) {
      // The page still renders an empty form and reports save/load failures explicitly.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final height = _height.text.trim().isEmpty ? null : double.tryParse(_height.text.trim());
    if (_height.text.trim().isNotEmpty && (height == null || height <= 0 || height > 300)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid height in centimetres.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{
        'preferred_name': _preferred.text.trim(),
        'legal_name': _legal.text.trim(),
        'sex_at_birth': _sex,
        'blood_group': _blood,
        if (_dob != null) 'date_of_birth': _dob!.toIso8601String().split('T').first,
        if (height != null) 'height_cm': height,
        if (_contact.text.trim().isNotEmpty) 'emergency_contact_name': _contact.text.trim(),
        if (_relationship.text.trim().isNotEmpty) 'emergency_contact_relationship': _relationship.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'emergency_contact_phone': _phone.text.trim(),
      };
      fields.removeWhere((key, value) => value is String && value.trim().isEmpty);
      if (_existing == null) {
        _existing = await patientRecords.create(resourceType: 'patient_profile', fields: fields);
      } else {
        _existing = await patientRecords.update(_existing!, fields: fields);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile encrypted and saved on this device.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your profile securely.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard}) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 110), children: [
      const Text('Your profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
      const SizedBox(height: 6),
      const Text('Your personal details and emergency contact information.', style: TextStyle(color: Color(0xFF69708E))),
      const SizedBox(height: 20),
      _field(_preferred, 'Preferred name'),
      _field(_legal, 'Legal name'),
      OutlinedButton.icon(
        onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: _dob ?? DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
          if (d != null) setState(() => _dob = d);
        },
        icon: const Icon(Icons.cake_outlined),
        label: Text(_dob == null ? 'Date of birth (optional)' : 'Date of birth: ${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _sex,
        decoration: const InputDecoration(labelText: 'Sex at birth', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'female', child: Text('Female')),
          DropdownMenuItem(value: 'male', child: Text('Male')),
          DropdownMenuItem(value: 'intersex', child: Text('Intersex')),
          DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
          DropdownMenuItem(value: 'not_recorded', child: Text('Prefer not to record')),
        ],
        onChanged: (v) => setState(() => _sex = v ?? 'not_recorded'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _blood,
        decoration: const InputDecoration(labelText: 'Blood group', border: OutlineInputBorder()),
        items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown', 'not_recorded']
          .map((v) => DropdownMenuItem(value: v, child: Text(v == 'not_recorded' ? 'Not recorded' : v))).toList(),
        onChanged: (v) => setState(() => _blood = v ?? 'not_recorded'),
      ),
      const SizedBox(height: 12),
      _field(_height, 'Height (cm)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
      const SizedBox(height: 10),
      const Text('Emergency contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
      const SizedBox(height: 12),
      _field(_contact, 'Contact name'),
      _field(_relationship, 'Relationship'),
      _field(_phone, 'Phone number', keyboard: TextInputType.phone),
      const SizedBox(height: 10),
      const Text('Profile details are encrypted locally. Emergency contacts are stored as information only; this stage does not provide emergency notification or emergency access.', style: TextStyle(fontSize: 12, color: Color(0xFF69708E), height: 1.4)),
      const SizedBox(height: 18),
      FilledButton(onPressed: _saving ? null : _save, child: Padding(padding: const EdgeInsets.all(14), child: Text(_saving ? 'Saving…' : 'Save profile securely'))),
    ]);
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title, subtitle;
  const PlaceholderPage({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.auto_awesome, size: 42, color: Color(0xFF7938DB)), const SizedBox(height: 14),
    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF171B3D))),
    const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF69708E))),
  ])));
}
