import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../../../core/supabase_client.dart';

final roomsProvider = StreamProvider<List<Room>>((ref) {
  return supabase
      .from('rooms')
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .map((r) => Room.fromMap((r['id']).toString(), {
                'name': r['name'],
                'building': r['building'],
                'capacity': r['capacity'],
                'isMaintenance': r['is_maintenance'] ?? false,
              }))
          .toList());
});

// Provider to get reservations with faculty names
final reservationsWithFacultyProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final nowIso = DateTime.now().toIso8601String();
  return supabase
      .from('room_reservations')
      .stream(primaryKey: ['id'])
      .gte('end_time', nowIso)
      .map((rows) => rows);
});

// Provider to cache faculty names
final facultyNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  try {
    final profiles = await supabase
        .from('profiles')
        .select('id, name')
        .inFilter('role', ['faculty', 'admin']);
    final Map<String, String> nameMap = {};
    for (final profile in profiles) {
      final id = profile['id'] as String?;
      final name = profile['name'] as String?;
      if (id != null && name != null) {
        nameMap[id] = name;
      }
    }
    return nameMap;
  } catch (_) {
    return {};
  }
});

class RoomAvailabilityScreen extends ConsumerWidget {
  const RoomAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);
    final reservationsAsync = ref.watch(reservationsWithFacultyProvider);
    final facultyNamesAsync = ref.watch(facultyNamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Availability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(reservationsWithFacultyProvider);
              ref.invalidate(roomsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          return reservationsAsync.when(
            data: (reservations) {
              // final now = DateTime.now();
              
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  // Find any approved reservation for this room
                  // The provider already filters by end_time >= now, so all reservations haven't ended
                  final roomReservations = reservations.where((r) {
                    final roomId = (r['room_id']).toString().trim();
                    final roomIdFromMap = r['room_id'];
                    final status = (r['status'] as String?)?.toLowerCase() ?? 'pending';
                    // Compare both as strings to handle UUID properly
                    final matchesRoom = roomId == room.id || 
                                       roomIdFromMap.toString() == room.id ||
                                       (roomIdFromMap is String && roomIdFromMap == room.id);
                    final isApproved = status == 'approved';
                    return matchesRoom && isApproved;
                  }).toList();
                  
                  // If there's ANY approved reservation that hasn't ended, show as reserved
                  final activeReservation = roomReservations.isNotEmpty ? roomReservations.first : null;
                  final facultyId = activeReservation?['created_by'] as String?;
                  final isAvailable = !room.isMaintenance && activeReservation == null;
                  
                  return Card(
                    color: isAvailable ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text('Building: ${room.building}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Capacity: ${room.capacity}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          if (isAvailable)
                            Chip(
                              label: const Text('Available', style: TextStyle(fontSize: 12)),
                              backgroundColor: Colors.green,
                              labelStyle: const TextStyle(color: Colors.white),
                            )
                          else
                            facultyNamesAsync.when(
                              data: (nameMap) {
                                final facultyName = nameMap[facultyId] ?? 'Unknown';
                                return Chip(
                                  label: Text(
                                    'Reserved by $facultyName',
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  backgroundColor: Colors.orange,
                                  labelStyle: const TextStyle(color: Colors.white),
                                );
                              },
                              loading: () => const Chip(
                                label: Text('Reserved', style: TextStyle(fontSize: 11)),
                                backgroundColor: Colors.orange,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                              error: (_, __) => const Chip(
                                label: Text('Reserved', style: TextStyle(fontSize: 11)),
                                backgroundColor: Colors.orange,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

