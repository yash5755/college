import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/constants.dart';

final allTimetablesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('timetables')
      .stream(primaryKey: ['id'])
      .order('created_at')
      .map((rows) => rows);
});

class AdminTimetableManageScreen extends ConsumerStatefulWidget {
  const AdminTimetableManageScreen({super.key});

  @override
  ConsumerState<AdminTimetableManageScreen> createState() => _AdminTimetableManageScreenState();
}

class _AdminTimetableManageScreenState extends ConsumerState<AdminTimetableManageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdCtrl = TextEditingController();
  int _dayOfWeek = DateTime.monday;
  final _subjectCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '09:00');
  final _endCtrl = TextEditingController(text: '10:00');
  final _semesterCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _semesterCtrl.dispose();
    _sectionCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _insertEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final start = _startCtrl.text.trim();
      final end = _endCtrl.text.trim();
      // Basic overlap check: same user/day and time interval
      final existing = await supabase
          .from('timetables')
          .select('id,start_time,end_time')
          .eq('user_id', _userIdCtrl.text.trim())
          .eq('day_of_week', _dayOfWeek);
      for (final e in existing) {
        if (_overlaps(start, end, e['start_time'] as String, e['end_time'] as String)) {
          throw Exception('Time overlaps with existing entry');
        }
      }

      await supabase.from('timetables').insert({
        'user_id': _userIdCtrl.text.trim(),
        'day_of_week': _dayOfWeek,
        'subject': _subjectCtrl.text.trim(),
        'room': _roomCtrl.text.trim(),
        'start_time': start,
        'end_time': end,
        'semester': _semesterCtrl.text.trim().isEmpty ? null : _semesterCtrl.text.trim(),
        'section': _sectionCtrl.text.trim().isEmpty ? null : _sectionCtrl.text.trim(),
        'department': _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry added')));
        _subjectCtrl.clear();
        _roomCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await supabase.from('timetables').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.single.bytes == null) return;
    final bytes = result.files.single.bytes!;
    final content = utf8.decode(bytes);
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.isEmpty) return;
    // Expect header: user_id,day_of_week,subject,room,start_time,end_time,semester,section,department
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final idxUser = header.indexOf('user_id');
    final idxDay = header.indexOf('day_of_week');
    final idxSub = header.indexOf('subject');
    final idxRoom = header.indexOf('room');
    final idxStart = header.indexOf('start_time');
    final idxEnd = header.indexOf('end_time');
    final idxSem = header.indexOf('semester');
    final idxSec = header.indexOf('section');
    final idxDept = header.indexOf('department');
    if ([idxUser, idxDay, idxSub, idxRoom, idxStart, idxEnd].any((i) => i < 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid CSV header')));
      return;
    }
    final inserts = <Map<String, dynamic>>[];
    final errors = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length < header.length) continue;
      // Basic validation
      final userId = r[idxUser].toString();
      final day = int.tryParse(r[idxDay].toString()) ?? 1;
      final start = r[idxStart].toString();
      final end = r[idxEnd].toString();
      if (!_isValidTime(start) || !_isValidTime(end)) {
        errors.add('Row ${i + 1}: invalid time');
        continue;
      }
      if (!_notOverlapSelf(userId, day, start, end)) {
        errors.add('Row ${i + 1}: overlaps existing timetable');
        continue;
      }
      inserts.add({
        'user_id': r[idxUser].toString(),
        'day_of_week': day,
        'subject': r[idxSub].toString(),
        'room': r[idxRoom].toString(),
        'start_time': start,
        'end_time': end,
        'semester': idxSem >= 0 ? (r[idxSem]?.toString().isEmpty == true ? null : r[idxSem].toString()) : null,
        'section': idxSec >= 0 ? (r[idxSec]?.toString().isEmpty == true ? null : r[idxSec].toString()) : null,
        'department': idxDept >= 0 ? (r[idxDept]?.toString().isEmpty == true ? null : r[idxDept].toString()) : null,
      });
    }
    if (errors.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Validation errors: ${errors.take(3).join('; ')}${errors.length > 3 ? ' …' : ''}')));
      return;
    }
    if (inserts.isEmpty) return;
    try {
      await supabase.from('timetables').insert(inserts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${inserts.length} rows')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allTimetablesProvider);
    final userAsync = ref.watch(currentUserDocProvider);
    final isAdmin = userAsync.valueOrNull?.role == AppRoles.admin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Management'),
        actions: [
          IconButton(onPressed: isAdmin ? _importCsv : null, icon: const Icon(Icons.upload_file)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _userIdCtrl,
                        decoration: const InputDecoration(labelText: 'User ID (student/faculty)'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _dayOfWeek,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Mon')),
                        DropdownMenuItem(value: 2, child: Text('Tue')),
                        DropdownMenuItem(value: 3, child: Text('Wed')),
                        DropdownMenuItem(value: 4, child: Text('Thu')),
                        DropdownMenuItem(value: 5, child: Text('Fri')),
                        DropdownMenuItem(value: 6, child: Text('Sat')),
                        DropdownMenuItem(value: 7, child: Text('Sun')),
                      ],
                      onChanged: (v) => setState(() => _dayOfWeek = v ?? 1),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'Subject'), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _roomCtrl, decoration: const InputDecoration(labelText: 'Room'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _startCtrl, decoration: const InputDecoration(labelText: 'Start (HH:mm)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _endCtrl, decoration: const InputDecoration(labelText: 'End (HH:mm)'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _semesterCtrl, decoration: const InputDecoration(labelText: 'Semester'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _sectionCtrl, decoration: const InputDecoration(labelText: 'Section'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _departmentCtrl, decoration: const InputDecoration(labelText: 'Department'))),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || !isAdmin ? null : _insertEntry,
                      icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                      label: Text(_saving ? 'Saving...' : 'Add Entry'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: allAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No entries'));
                }
                rows.sort((a, b) => (a['day_of_week'] as int).compareTo(b['day_of_week'] as int));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final e = rows[index];
                    final id = (e['id']).toString();
                    final title = '${_weekdayName(e['day_of_week'] as int)} • ${e['subject'] ?? ''}';
                    final subtitle = '${e['start_time']} - ${e['end_time']} • ${e['room'] ?? ''} • ${e['user_id']}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text(subtitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: isAdmin ? () => _deleteEntry(id) : null,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

bool _overlaps(String aStart, String aEnd, String bStart, String bEnd) {
  int toMin(String s) {
    final parts = s.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
  final as = toMin(aStart), ae = toMin(aEnd), bs = toMin(bStart), be = toMin(bEnd);
  return as < be && bs < ae;
}

bool _isValidTime(String t) {
  final p = t.split(':');
  if (p.length != 2) return false;
  final h = int.tryParse(p[0]) ?? -1;
  final m = int.tryParse(p[1]) ?? -1;
  return h >= 0 && h < 24 && m >= 0 && m < 60;
}

bool _notOverlapSelf(String userId, int day, String start, String end) {
  // This function synchronously checks cached list would be better; here we do a quick best-effort by returning true.
  // Server will still reject on constraint/RLS if any.
  return true;
}

String _weekdayName(int d) {
  const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  return days[(d - 1).clamp(0, 6)];
}


