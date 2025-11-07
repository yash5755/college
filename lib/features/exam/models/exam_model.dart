class ExamAllocation {
  final String id;
  final String examId;
  final String studentId;
  final String studentUSN;
  final String studentName;
  final String roomId;
  final String roomName;
  final String seatNumber;
  final DateTime examDate;
  final String examTime;
  final String subject;
  final String semester;
  final String section;

  const ExamAllocation({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentUSN,
    required this.studentName,
    required this.roomId,
    required this.roomName,
    required this.seatNumber,
    required this.examDate,
    required this.examTime,
    required this.subject,
    required this.semester,
    required this.section,
  });

  factory ExamAllocation.fromMap(String id, Map<String, dynamic> data) {
    return ExamAllocation(
      id: id,
      examId: (data['examId'] as String?) ?? (data['exam_id'] as String?) ?? '',
      studentId: (data['studentId'] as String?) ?? (data['student_id'] as String?) ?? '',
      studentUSN: (data['studentUSN'] as String?) ?? (data['student_usn'] as String?) ?? '',
      studentName: (data['studentName'] as String?) ?? (data['student_name'] as String?) ?? '',
      roomId: (data['roomId'] as String?) ?? (data['room_id'] as String?) ?? '',
      roomName: (data['roomName'] as String?) ?? (data['room_name'] as String?) ?? '',
      seatNumber: (data['seatNumber'] as String?) ?? (data['seat_number'] as String?) ?? '',
      examDate: _parseDateTime(data['examDate']) ?? _parseDateTime(data['exam_date']) ?? DateTime.now(),
      examTime: (data['examTime'] as String?) ?? (data['exam_time'] as String?) ?? '',
      subject: (data['subject'] as String?) ?? '',
      semester: (data['semester'] as String?) ?? '',
      section: (data['section'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'examId': examId,
      'studentId': studentId,
      'studentUSN': studentUSN,
      'studentName': studentName,
      'roomId': roomId,
      'roomName': roomName,
      'seatNumber': seatNumber,
      'examDate': examDate.toIso8601String(),
      'examTime': examTime,
      'subject': subject,
      'semester': semester,
      'section': section,
    };
  }
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  try { return DateTime.parse(s); } catch (_) { return null; }
}

