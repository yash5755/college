import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase_client.dart';
import '../../dashboard/providers/portal_providers.dart';

final allExamAllocationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('exam_allocations')
      .stream(primaryKey: ['id'])
      .order('exam_date', ascending: false)
      .map((rows) {
        // Group by exam (exam_id, subject, exam_date, exam_time)
        final examGroups = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          final examId = row['exam_id']?.toString() ?? '';
          final subject = row['subject']?.toString() ?? '';
          final examDate = row['exam_date']?.toString() ?? '';
          final examTime = row['exam_time']?.toString() ?? '';
          final key = '$examId|$subject|$examDate|$examTime';
          examGroups.putIfAbsent(key, () => []).add(row);
        }
        
        // Convert to list of exam summaries
        final exams = <Map<String, dynamic>>[];
        for (final entry in examGroups.entries) {
          final allocations = entry.value;
          if (allocations.isEmpty) continue;
          
          final first = allocations.first;
          final uniqueRooms = allocations.map((a) => a['room_name']?.toString() ?? '').where((r) => r.isNotEmpty).toSet().toList();
          final uniqueStudents = allocations.map((a) => a['student_id']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().length;
          
          exams.add({
            'exam_id': first['exam_id']?.toString() ?? '',
            'subject': first['subject']?.toString() ?? 'Unknown',
            'exam_date': first['exam_date']?.toString() ?? '',
            'exam_time': first['exam_time']?.toString() ?? '',
            'student_count': uniqueStudents,
            'room_count': uniqueRooms.length,
            'rooms': uniqueRooms,
            'allocations': allocations,
            'first_allocation_id': first['id']?.toString() ?? '',
          });
        }
        
        return exams;
      });
});

class AdminExamManageScreen extends ConsumerWidget {
  const AdminExamManageScreen({super.key});

  Future<void> _deleteExam(BuildContext context, WidgetRef ref, Map<String, dynamic> exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exam Allocation'),
        content: Text(
          'Are you sure you want to delete all allocations for "${exam['subject']}" on ${exam['exam_date']?.toString().substring(0, 10) ?? ''}? '
          'This will delete ${exam['student_count']} student allocations and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Get all allocation IDs for this exam
      final allocations = exam['allocations'] as List<Map<String, dynamic>>;
      final allocationIds = allocations.map((a) => a['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      
      if (allocationIds.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No allocations found to delete')),
          );
        }
        return;
      }

      // Delete all allocations
      await supabase.from('exam_allocations').delete().inFilter('id', allocationIds);
      
      // Delete related invigilator announcements
      final examDateStr = exam['exam_date']?.toString().substring(0, 10) ?? '';
      final examTimeStr = exam['exam_time']?.toString() ?? '';
      final subject = exam['subject']?.toString() ?? '';
      
      // Find and delete invigilator announcements for this exam
      final announcements = await supabase
          .from('announcements')
          .select('id, body')
          .eq('title', 'Invigilation Duty Assigned');
      
      final announcementIdsToDelete = <String>[];
      for (final ann in announcements) {
        final body = ann['body']?.toString() ?? '';
        if (body.contains(subject) && body.contains(examDateStr) && body.contains(examTimeStr)) {
          announcementIdsToDelete.add(ann['id']?.toString() ?? '');
        }
      }
      
      if (announcementIdsToDelete.isNotEmpty) {
        await supabase.from('announcements').delete().inFilter('id', announcementIdsToDelete);
      }
      
      // Delete student exam allocation announcements
      final studentAnnouncements = await supabase
          .from('announcements')
          .select('id, body')
          .eq('title', 'Exam Seat Allocated');
      
      final studentAnnIdsToDelete = <String>[];
      for (final ann in studentAnnouncements) {
        final body = ann['body']?.toString() ?? '';
        if (body.contains(subject) && body.contains(examDateStr) && body.contains(examTimeStr)) {
          studentAnnIdsToDelete.add(ann['id']?.toString() ?? '');
        }
      }
      
      if (studentAnnIdsToDelete.isNotEmpty) {
        await supabase.from('announcements').delete().inFilter('id', studentAnnIdsToDelete);
      }
      
      // Invalidate streams to refresh UI
      ref.invalidate(allExamAllocationsProvider);
      ref.invalidate(announcementsStreamProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${allocationIds.length} exam allocations'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting exam: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(allExamAllocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Exam Allocations'),
      ),
      body: examsAsync.when(
        data: (exams) {
          if (exams.isEmpty) {
            return const Center(child: Text('No exam allocations found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allExamAllocationsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exams.length,
              itemBuilder: (context, index) {
                final exam = exams[index];
                final examDate = DateTime.tryParse(exam['exam_date']?.toString() ?? '') ?? DateTime.now();
                final examTime = exam['exam_time']?.toString() ?? '';
                final subject = exam['subject']?.toString() ?? 'Unknown';
                final studentCount = exam['student_count'] as int? ?? 0;
                final roomCount = exam['room_count'] as int? ?? 0;
                final rooms = exam['rooms'] as List<String>? ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('MMM dd, yyyy').format(examDate)} at $examTime',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteExam(context, ref, exam),
                              tooltip: 'Delete exam',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.people,
                              label: '$studentCount students',
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.meeting_room,
                              label: '$roomCount room${roomCount != 1 ? 's' : ''}',
                            ),
                          ],
                        ),
                        if (rooms.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: rooms.take(5).map((room) => Chip(
                              label: Text(room, style: const TextStyle(fontSize: 12)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

