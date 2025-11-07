import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';
import '../models/room_model.dart';

final pendingReservationsProvider = StreamProvider<List<RoomReservation>>((ref) {
  return supabase
      .from('room_reservations')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('start_time')
      .map((rows) => rows
          .map((r) => RoomReservation.fromMap((r['id']).toString(), {
                'room_id': (r['room_id']).toString(),
                'created_by': r['created_by'],
                'start_time': r['start_time'],
                'end_time': r['end_time'],
                'purpose': r['purpose'],
                'status': r['status'],
              }))
          .toList());
});

class ReservationApprovalsScreen extends ConsumerWidget {
  const ReservationApprovalsScreen({super.key});

  Future<void> _updateStatus(String id, String status, BuildContext context) async {
    try {
      await supabase.from('room_reservations').update({'status': status}).eq('id', id);
      if (status == 'approved') {
        try {
          final row = await supabase.from('room_reservations').select('room_id,start_time,end_time,created_by').eq('id', id).maybeSingle();
          if (row != null) {
            final room = row['room_id'].toString();
            final start = DateTime.parse(row['start_time'].toString()).toLocal();
            final end = DateTime.parse(row['end_time'].toString()).toLocal();
            await supabase.from('announcements').insert({
              'title': 'Room Booking Approved',
              'body': 'Room $room from ${start.toString()} to ${end.toString()} has been approved.',
              'audience': ['faculty'],
              'created_by': row['created_by'],
            });
          }
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reservation ${status.toLowerCase()}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(pendingReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Approvals')),
      body: reservationsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No pending reservations'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final r = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room: ${r.roomId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Start: ${r.startTime.toLocal()}'),
                      Text('End: ${r.endTime.toLocal()}'),
                      if (r.purpose != null) Text('Purpose: ${r.purpose}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _updateStatus(r.id, 'rejected', context),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _updateStatus(r.id, 'approved', context),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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


