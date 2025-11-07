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
      TimetableEntry? nextClass; // For demo: show next class if no current class
      Map<String, dynamic>? roomRow;
      Map<String, dynamic>? facultyRow;
      
      // First, try to find current class (time is within range)
      for (final e in entries) {
        final start = (e['start_time'] as String?) ?? '';
        final end = (e['end_time'] as String?) ?? '';
        if (start.isEmpty || end.isEmpty) continue;
        
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
          break;
        }
      }
      
      // If no current class found, find the next upcoming class for demo purposes
      if (currentClass == null && entries.isNotEmpty) {
        final currentMinutes = _timeToMinutes(currentTime);
        TimetableEntry? closestNext;
        int? closestMinutes;
        
        for (final e in entries) {
          final start = (e['start_time'] as String?) ?? '';
          final end = (e['end_time'] as String?) ?? '';
          if (start.isEmpty || end.isEmpty) continue;
          
          final startMinutes = _timeToMinutes(start);
          // Find the next class that hasn't ended yet, or the closest upcoming one
          if (startMinutes >= currentMinutes || _timeToMinutes(end) >= currentMinutes) {
            if (closestNext == null || startMinutes < (closestMinutes ?? 9999)) {
              closestNext = TimetableEntry(
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
              closestMinutes = startMinutes;
            }
          }
        }
        
        // If still no class found, use the first class of the day for demo
        if (closestNext == null && entries.isNotEmpty) {
          final firstEntry = entries.first;
          final start = (firstEntry['start_time'] as String?) ?? '';
          final end = (firstEntry['end_time'] as String?) ?? '';
          if (start.isNotEmpty && end.isNotEmpty) {
            closestNext = TimetableEntry(
              id: (firstEntry['id']).toString(),
              studentId: uid,
              facultyId: firstEntry['faculty_id'] as String?,
              roomId: (firstEntry['room_id'] ?? '') as String,
              roomName: (firstEntry['room'] ?? '') as String,
              subject: (firstEntry['subject'] ?? '') as String,
              dayOfWeek: weekday.toString(),
              startTime: start,
              endTime: end,
              semester: firstEntry['semester'] as String?,
              section: firstEntry['section'] as String?,
              department: firstEntry['department'] as String?,
            );
          }
        }
        
        currentClass = closestNext;
      }
      
      // Get room and faculty details for the selected class
      if (currentClass != null) {
        final rid = currentClass.roomId;
        final roomNameText = currentClass.roomName;
        if (rid.isNotEmpty) {
          try {
            roomRow = await client.from('rooms').select().eq('id', rid).maybeSingle();
          } catch (_) {
            // If room_id lookup fails, try to find by room name
            if (roomNameText.isNotEmpty) {
              try {
                roomRow = await client.from('rooms').select().eq('name', roomNameText).maybeSingle();
              } catch (_) {}
            }
          }
        } else if (roomNameText.isNotEmpty) {
          // If no room_id, try to find by room name
          try {
            roomRow = await client.from('rooms').select().eq('name', roomNameText).maybeSingle();
          } catch (_) {}
        }
        
        final fid = currentClass.facultyId;
        if (fid != null && fid.isNotEmpty) {
          try {
            facultyRow = await client.from('profiles').select('id,name,department').eq('id', fid).maybeSingle();
          } catch (_) {}
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
  try {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  } catch (_) {
    return 0;
  }
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
                    subtitle: 'Type a USN to find current class and room\n\nExample: 4TV24CS001',
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

