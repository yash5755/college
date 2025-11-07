import '../core/constants.dart';
import 'supabase_client.dart';

/// Seeds minimal demo data for Student Locator and Timetable features.
/// Safe to run multiple times (uses merge and idempotent checks).
Future<void> seedDemoData() async {

  // Demo users
  final users = [
    {
      'uid': 'demo-student-1',
      'email': 'student1@vvce.ac.in',
      'role': AppRoles.student,
      'displayName': 'Student One',
      'department': 'CSE',
      'usn': '4VV21CS001',
    },
    {
      'uid': 'demo-student-2',
      'email': 'student2@vvce.ac.in',
      'role': AppRoles.student,
      'displayName': 'Student Two',
      'department': 'ECE',
      'usn': '4VV21EC002',
    },
    {
      'uid': 'demo-faculty-1',
      'email': 'faculty1@vvce.ac.in',
      'role': AppRoles.faculty,
      'displayName': 'Dr. A. Faculty',
      'department': 'CSE',
    },
    {
      'uid': 'demo-admin-1',
      'email': 'admin@vvce.ac.in',
      'role': AppRoles.admin,
      'displayName': 'System Admin',
      'department': 'Admin',
    },
  ];

  // Seed profiles
  for (final u in users) {
    await supabase.from('profiles').upsert({
      'id': u['uid'],
      'email': u['email'],
      'role': u['role'],
      'name': u['displayName'],
      'department': u['department'],
      'usn': u['usn'],
    });
  }

  // Demo rooms
  final rooms = [
    {
      'id': 'R-101',
      'name': 'Room 101',
      'building': 'Block A',
      'capacity': 60,
      'type': 'Classroom',
      'isMaintenance': false,
    },
    {
      'id': 'R-201',
      'name': 'Room 201',
      'building': 'Block B',
      'capacity': 45,
      'type': 'Classroom',
      'isMaintenance': false,
    },
  ];
  for (final r in rooms) {
    await supabase.from('rooms').upsert({
      'id': r['id'],
      'name': r['name'],
      'building': r['building'],
      'capacity': r['capacity'],
      'room_type': r['type'],
      'is_maintenance': r['isMaintenance'],
    });
  }

  // Demo timetable for demo-student-1 (Mon-Fri two classes)
  final timetableDocs = [
    {
      'id': 'tt-s1-mon-1',
      'user_id': 'demo-student-1',
      'room_id': 'R-101',
      'room': 'Room 101',
      'subject': 'Data Structures',
      'day_of_week': 1,
      'start_time': '09:00',
      'end_time': '10:00',
      'semester': '3',
      'section': 'A',
      'department': 'CSE',
    },
    {
      'id': 'tt-s1-mon-2',
      'user_id': 'demo-student-1',
      'room_id': 'R-201',
      'room': 'Room 201',
      'subject': 'OOP',
      'day_of_week': 1,
      'start_time': '10:15',
      'end_time': '11:15',
      'semester': '3',
      'section': 'A',
      'department': 'CSE',
    },
    {
      'id': 'tt-s1-tue-1',
      'user_id': 'demo-student-1',
      'room_id': 'R-101',
      'room': 'Room 101',
      'subject': 'Discrete Math',
      'day_of_week': 2,
      'start_time': '09:00',
      'end_time': '10:00',
      'semester': '3',
      'section': 'A',
      'department': 'CSE',
    },
  ];
  for (final t in timetableDocs) {
    await supabase.from('timetables').upsert(t);
  }
}


