import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo_config.dart';
import '../models/timetable_model.dart';
import '../../../core/supabase_client.dart';

final studentTimetableProvider = StreamProvider<List<TimetableEntry>>((ref) {
  final user = supabase.auth.currentUser;
  final demoStudentId = 'demo-student-1';
  final effectiveStudentId = kDemoModeEnabled ? demoStudentId : user?.id;
  if (effectiveStudentId == null) return Stream.value([]);

  return supabase
      .from('timetables')
      .stream(primaryKey: ['id'])
      .eq('user_id', effectiveStudentId)
      .map((rows) => rows
          .map((e) => TimetableEntry(
                id: (e['id']).toString(),
                studentId: effectiveStudentId,
                facultyId: e['faculty_id'] as String?,
                roomId: (e['room_id'] ?? '') as String,
                roomName: (e['room'] ?? '') as String,
                subject: (e['subject'] ?? '') as String,
                dayOfWeek: _weekdayToName(e['day_of_week'] as int? ?? 1),
                startTime: (e['start_time'] ?? '') as String,
                endTime: (e['end_time'] ?? '') as String,
                semester: e['semester'] as String?,
                section: e['section'] as String?,
                department: e['department'] as String?,
              ))
          .toList());
});

class StudentTimetableScreen extends ConsumerWidget {
  const StudentTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(studentTimetableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Timetable')),
      body: timetableAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No timetable entries found'));
          }

          // Group by day
          final grouped = <String, List<TimetableEntry>>{};
          for (final entry in entries) {
            grouped.putIfAbsent(entry.dayOfWeek, () => []).add(entry);
          }

          const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final dayEntries = grouped[day] ?? [];
              
              if (dayEntries.isEmpty) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: dayEntries.map((entry) {
                    return ListTile(
                      title: Text(entry.subject),
                      subtitle: Text('${entry.startTime} - ${entry.endTime}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(entry.roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (entry.facultyId != null) const Text('Faculty', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

String _weekdayToName(int weekday) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[(weekday - 1).clamp(0, 6)];
}

