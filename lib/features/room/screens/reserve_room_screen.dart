import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import 'room_availability_screen.dart';
import '../../../core/supabase_client.dart';

class ReserveRoomScreen extends ConsumerStatefulWidget {
  const ReserveRoomScreen({super.key});

  @override
  ConsumerState<ReserveRoomScreen> createState() => _ReserveRoomScreenState();
}

class _ReserveRoomScreenState extends ConsumerState<ReserveRoomScreen> {
  Room? _selectedRoom;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final _purposeController = TextEditingController();

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _submitReservation() async {
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    // Check if user is faculty - auto-approve for faculty
    final userProfile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final isFaculty = userProfile?['role'] == 'faculty' || userProfile?['role'] == 'admin';
    
    final reservation = RoomReservation(
      id: '',
      roomId: _selectedRoom!.id,
      facultyId: user.id,
      startTime: startDateTime,
      endTime: endDateTime,
      purpose: _purposeController.text.trim().isEmpty ? null : _purposeController.text.trim(),
      status: isFaculty ? 'approved' : 'pending', // Auto-approve for faculty/admin
    );

    try {
      // Conflict check: overlapping reservations for the same room
      final startIso = reservation.startTime.toIso8601String();
      final endIso = reservation.endTime.toIso8601String();
      // Overlap condition: a.start < b.end AND b.start < a.end
      final conflicts = await supabase
          .from('room_reservations')
          .select('id')
          .eq('room_id', reservation.roomId)
          .inFilter('status', ['approved', 'pending'])
          .lt('start_time', endIso)
          .gt('end_time', startIso);
      if (conflicts.isNotEmpty) {
        // Suggest alternative rooms at same time
        final sameTimeFreeRooms = await supabase
            .from('rooms')
            .select()
            .eq('is_maintenance', false);

        final busyRoomIdsRows = await supabase
            .from('room_reservations')
            .select('room_id')
            .inFilter('status', ['approved','pending'])
            .lt('start_time', endIso)
            .gt('end_time', startIso);
        final busyIds = busyRoomIdsRows.map((r) => (r['room_id']).toString()).toSet();
        final alternatives = (sameTimeFreeRooms as List)
            .where((r) => !busyIds.contains(r['id'].toString()))
            .take(5)
            .toList();

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Time Conflict'),
            content: alternatives.isEmpty
                ? const Text('Selected slot is busy. Try a different time.')
                : SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('These rooms are free at the selected time:'),
                        const SizedBox(height: 8),
                        ...alternatives.map((r) => ListTile(
                              dense: true,
                              title: Text(r['name']?.toString() ?? ''),
                              subtitle: Text('Capacity: ${r['capacity'] ?? '-'}'),
                              onTap: () {
                                setState(() {
                                  _selectedRoom = Room(
                                    id: r['id'].toString(),
                                    name: r['name']?.toString() ?? '',
                                    building: (r['building']?.toString() ?? ''),
                                    capacity: (r['capacity'] as int?) ?? 40,
                                    isMaintenance: (r['is_maintenance'] as bool?) ?? false,
                                  );
                                });
                                Navigator.of(ctx).pop();
                              },
                            )),
                      ],
                    ),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          ),
        );
        return;
      }

      await supabase.from('room_reservations').insert({
        'room_id': reservation.roomId,
        'start_time': reservation.startTime.toIso8601String(),
        'end_time': reservation.endTime.toIso8601String(),
        'purpose': reservation.purpose,
        'status': reservation.status,
        'created_by': user.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFaculty 
              ? 'Room reserved successfully!' 
              : 'Reservation submitted for approval'),
            backgroundColor: isFaculty ? Colors.green : Colors.blue,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reserve Room')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            roomsAsync.when(
              data: (rooms) {
                final availableRooms = rooms.where((r) => !r.isMaintenance).toList();
                return DropdownButtonFormField<Room>(
                  decoration: const InputDecoration(labelText: 'Select Room'),
                  value: _selectedRoom,
                  items: availableRooms
                      .map((room) => DropdownMenuItem(
                            value: room,
                            child: Text('${room.name} - ${room.building} (${room.capacity} seats)'),
                          ))
                      .toList(),
                  onChanged: (room) => setState(() => _selectedRoom = room),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date'),
              subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_startTime.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime,
                );
                if (time != null) setState(() => _startTime = time);
              },
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(_endTime.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _endTime,
                );
                if (time != null) setState(() => _endTime = time);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Purpose (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitReservation,
              child: const Text('Submit Reservation'),
            ),
          ],
        ),
      ),
    );
  }
}

