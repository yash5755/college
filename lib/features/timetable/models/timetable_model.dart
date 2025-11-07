class TimetableEntry {
  final String id;
  final String? studentId; // null if faculty timetable
  final String? facultyId; // null if student timetable
  final String roomId;
  final String roomName;
  final String subject;
  final String dayOfWeek; // Monday, Tuesday, etc.
  final String startTime; // HH:mm format
  final String endTime; // HH:mm format
  final String? semester;
  final String? section;
  final String? department;

  const TimetableEntry({
    required this.id,
    this.studentId,
    this.facultyId,
    required this.roomId,
    required this.roomName,
    required this.subject,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.semester,
    this.section,
    this.department,
  });

  factory TimetableEntry.fromMap(String id, Map<String, dynamic> data) {
    return TimetableEntry(
      id: id,
      studentId: data['studentId'] as String?,
      facultyId: data['facultyId'] as String?,
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as String? ?? '',
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      semester: data['semester'] as String?,
      section: data['section'] as String?,
      department: data['department'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'facultyId': facultyId,
      'roomId': roomId,
      'roomName': roomName,
      'subject': subject,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'semester': semester,
      'section': section,
      'department': department,
    };
  }
}

