import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/exam_model.dart';
import '../../../core/supabase_client.dart';
import 'dart:convert';

final studentExamAllocationsProvider = StreamProvider<List<ExamAllocation>>((ref) {
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value([]);
  return supabase
      .from('exam_allocations')
      .stream(primaryKey: ['id'])
      .eq('student_id', user.id)
      .map((rows) {
        final result = <ExamAllocation>[];
        for (final e in rows) {
          try {
            result.add(ExamAllocation(
              id: (e['id']).toString(),
              examId: (e['exam_id'] ?? '').toString(),
              studentId: (e['student_id'] ?? '').toString(),
              studentUSN: (e['student_usn'] ?? '') as String,
              studentName: (e['student_name'] ?? '') as String,
              roomId: (e['room_id'] ?? '').toString(),
              roomName: (e['room_name'] ?? '') as String,
              seatNumber: (e['seat_number'] ?? '').toString(),
              examDate: DateTime.parse((e['exam_date'] ?? e['created_at']).toString()),
              examTime: (e['exam_time'] ?? '') as String,
              subject: (e['subject'] ?? '') as String,
              semester: (e['semester'] ?? '')?.toString() ?? '',
              section: (e['section'] ?? '')?.toString() ?? '',
            ));
          } catch (_) {}
        }
        return result;
      });
});

class ExamNotificationsScreen extends ConsumerWidget {
  const ExamNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(studentExamAllocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Allocations')),
      body: examsAsync.when(
        data: (allocations) {
          if (allocations.isEmpty) {
            return const Center(child: Text('No exam allocations found'));
          }

          final now = DateTime.now();
          final upcoming = allocations.where((a) => a.examDate.isAfter(now)).toList();
          final past = allocations.where((a) => a.examDate.isBefore(now)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                const Text(
                  'Upcoming Exams',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...upcoming.map((alloc) => _ExamCard(alloc, isUpcoming: true)),
                const SizedBox(height: 24),
              ],
              if (past.isNotEmpty) ...[
                const Text(
                  'Past Exams',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...past.map((alloc) => _ExamCard(alloc, isUpcoming: false)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard(this.allocation, {required this.isUpcoming});
  final ExamAllocation allocation;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isUpcoming ? Colors.blue.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              allocation.subject,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: ${DateFormat('MMM dd, yyyy').format(allocation.examDate)}'),
            Text('Time: ${allocation.examTime}'),
            Text('Room: ${allocation.roomName}'),
            Text('Seat: ${allocation.seatNumber}'),
            Text('Section: ${allocation.section}'),
          ],
        ),
      ),
    );
  }
}

