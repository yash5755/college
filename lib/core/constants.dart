// Core constants for roles, colors, and collection names

class AppRoles {
  static const String admin = 'admin';
  static const String faculty = 'faculty';
  static const String student = 'student';

  static const List<String> all = [admin, faculty, student];
}

class FirestoreCollections {
  static const String users = 'users';
  static const String rooms = 'rooms';
  static const String timetables = 'timetables';
  static const String classes = 'classes';
  static const String exams = 'exams';
  static const String allocations = 'allocations';
  static const String reservations = 'reservations';
}

class AppColors {
  static const int primaryHex = 0xFF1E40AF; // Deep Blue
  static const int secondaryHex = 0xFFF8FAFC; // Light Gray
  static const int accentHex = 0xFF10B981; // Green
}

