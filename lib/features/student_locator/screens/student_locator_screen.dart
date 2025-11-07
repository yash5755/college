import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../timetable/models/timetable_model.dart';
import '../../user/models/user_model.dart';
import '../../../core/supabase_client.dart';

final studentSearchProvider = StateProvider<String>((ref) => '');

final studentLocatorProvider = StreamProvider.family<List<StudentLocation>, String>((ref, query) {
  if (query.isEmpty) return Stream.value([]);
  final client = supabase;
  // Build a stream that reacts to profile changes and recomputes results
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('role', AppRoles.student)
      .map((rows) async {
    final now = DateTime.now();
    final weekday = now.weekday; // 1-7
    final currentTime = _formatTime(now);
    final q = query.toLowerCase();
    final matches = rows.where((p) {
      final usn = (p['usn'] as String?)?.toLowerCase() ?? '';
      return usn.contains(q);
    }).toList();

    final result = <StudentLocation>[];
    for (final p in matches) {
      final uid = p['id'] as String;
      // Fetch today's timetable entries for this user
      final entries = await client
          .from('timetables')
          .select()
          .eq('user_id', uid)
          .eq('day_of_week', weekday)
          .order('start_time')
          .limit(10);
      TimetableEntry? currentClass;
      Map<String, dynamic>? roomRow;
      Map<String, dynamic>? facultyRow;
      for (final e in entries) {
        final start = (e['start_time'] as String?) ?? '';
        final end = (e['end_time'] as String?) ?? '';
        if (_isTimeInRange(currentTime, start, end)) {
          currentClass = TimetableEntry(
            id: (e['id']).toString(),
            studentId: uid,
            facultyId: e['faculty_id'] as String?,
            roomId: (e['room_id'] ?? '') as String,
            roomName: (e['room'] ?? '') as String,
            subject: (e['subject'] ?? '') as String,
            dayOfWeek: weekday.toString(),
            startTime: start,
            endTime: end,
            semester: e['semester'] as String?,
            section: e['section'] as String?,
            department: e['department'] as String?,
          );
          final rid = e['room_id'] as String?;
          if (rid != null && rid.isNotEmpty) {
            roomRow = await client.from('rooms').select().eq('id', rid).maybeSingle();
          }
          final fid = e['faculty_id'] as String?;
          if (fid != null && fid.isNotEmpty) {
            facultyRow = await client.from('profiles').select('id,name,department').eq('id', fid).maybeSingle();
          }
          break;
        }
      }
      result.add(
        StudentLocation(
          student: AppUser(
            uid: uid,
            email: (p['email'] as String?) ?? '',
            role: (p['role'] as String?) ?? AppRoles.student,
            displayName: p['name'] as String?,
            department: p['department'] as String?,
            photoUrl: p['profile_pic'] as String?,
            usn: p['usn'] as String?,
            phone: p['phone'] as String?,
          ),
          currentClass: currentClass,
          roomBuilding: roomRow != null ? (roomRow!['building'] as String?) : null,
          facultyName: facultyRow != null ? (facultyRow!['name'] as String?) : null,
        ),
      );
    }
    return result;
  }).asyncMap((f) => f);
});

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

bool _isTimeInRange(String current, String start, String end) {
  final currentMin = _timeToMinutes(current);
  final startMin = _timeToMinutes(start);
  final endMin = _timeToMinutes(end);
  return currentMin >= startMin && currentMin <= endMin;
}

int _timeToMinutes(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

class StudentLocation {
  final AppUser student;
  final TimetableEntry? currentClass;
  final String? roomBuilding;
  final String? facultyName;

  StudentLocation({required this.student, this.currentClass, this.roomBuilding, this.facultyName});
}

class StudentLocatorScreen extends ConsumerWidget {
  const StudentLocatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(studentSearchProvider);
    final locationsAsync = ref.watch(studentLocatorProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Student Locator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by USN (e.g., 1VVXX...)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => ref.read(studentSearchProvider.notifier).state = '',
                            )
                          : null,
                    ),
                    onChanged: (value) => ref.read(studentSearchProvider.notifier).state = value,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: locationsAsync.when(
              data: (locations) {
                if (query.isEmpty) {
                  return _EmptyState(
                    icon: Icons.search_rounded,
                    title: 'Search Students',
                    subtitle: 'Type a USN to find current class and room',
                  );
                }
                if (locations.isEmpty) {
                  return _EmptyState(
                    icon: Icons.person_search,
                    title: 'No results',
                    subtitle: 'Try a different USN or check spelling',
                  );
                }
                return ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    final hasClass = loc.currentClass != null;
                    return _ResultTile(location: loc, hasClass: hasClass);
                  },
                );
              },
              loading: () => const _LoadingList(),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatefulWidget {
  const _ResultTile({required this.location, required this.hasClass});
  final StudentLocation location;
  final bool hasClass;
  @override
  State<_ResultTile> createState() => _ResultTileState();
}

class _ResultTileState extends State<_ResultTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final initials = (loc.student.displayName ?? loc.student.email)
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.student.displayName ?? loc.student.email,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (loc.student.usn != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${loc.student.usn}', style: TextStyle(color: Colors.grey.shade800, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (widget.hasClass) ...[
                        Row(children: [
                          const Icon(Icons.class_, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${loc.currentClass!.subject} • ${loc.currentClass!.startTime}-${loc.currentClass!.endTime}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${loc.currentClass!.roomName}${loc.roomBuilding != null ? ' • ${loc.roomBuilding}' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        if (loc.facultyName != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.person, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text('${loc.facultyName}')),
                          ]),
                        ],
                      ] else ...[
                        Row(children: const [
                          Icon(Icons.info_outline, size: 16),
                          SizedBox(width: 6),
                          Expanded(child: Text('No current class')),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(height: 48, width: 48, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: double.infinity, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 180, color: Colors.grey.shade200),
                      const SizedBox(height: 6),
                      Container(height: 12, width: 120, color: Colors.grey.shade200),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

