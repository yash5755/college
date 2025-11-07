class Room {
  final String id;
  final String name;
  final String building;
  final int capacity;
  final String? type; // lecture, lab, etc.
  final bool isMaintenance;
  final Map<String, dynamic>? metadata;

  const Room({
    required this.id,
    required this.name,
    required this.building,
    required this.capacity,
    this.type,
    this.isMaintenance = false,
    this.metadata,
  });

  factory Room.fromMap(String id, Map<String, dynamic> data) {
    return Room(
      id: id,
      name: data['name'] as String? ?? '',
      building: data['building'] as String? ?? '',
      capacity: data['capacity'] as int? ?? 0,
      type: data['type'] as String?,
      isMaintenance: (data['isMaintenance'] as bool?) ?? (data['is_maintenance'] as bool?) ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'building': building,
      'capacity': capacity,
      'type': type,
      'isMaintenance': isMaintenance,
      'metadata': metadata,
    };
  }
}

class RoomReservation {
  final String id;
  final String roomId;
  final String facultyId;
  final DateTime startTime;
  final DateTime endTime;
  final String? purpose;
  final String status; // pending, approved, rejected

  const RoomReservation({
    required this.id,
    required this.roomId,
    required this.facultyId,
    required this.startTime,
    required this.endTime,
    this.purpose,
    this.status = 'pending',
  });

  factory RoomReservation.fromMap(String id, Map<String, dynamic> data) {
    return RoomReservation(
      id: id,
      roomId: (data['roomId'] as String?) ?? (data['room_id'] as String?) ?? '',
      facultyId: (data['facultyId'] as String?) ?? (data['created_by'] as String?) ?? '',
      startTime: _parseDateTime(data['startTime']) ?? _parseDateTime(data['start_time']) ?? DateTime.now(),
      endTime: _parseDateTime(data['endTime']) ?? _parseDateTime(data['end_time']) ?? DateTime.now(),
      purpose: data['purpose'] as String?,
      status: data['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'facultyId': facultyId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'purpose': purpose,
      'status': status,
    };
  }
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  try { return DateTime.parse(s); } catch (_) { return null; }
}

