class AppUser {
  final String uid;
  final String email;
  final String role; // admin | faculty | student
  final String? displayName;
  final String? department;
  final String? photoUrl;
  final String? usn; // for students
  final String? phone;
  final bool approved;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.department,
    this.photoUrl,
    this.usn,
    this.phone,
    this.approved = true,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      uid: id,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      displayName: data['displayName'] as String?,
      department: data['department'] as String?,
      photoUrl: data['photoUrl'] as String?,
      usn: data['usn'] as String?,
      phone: data['phone'] as String?,
      approved: (data['approved'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'displayName': displayName,
      'department': department,
      'photoUrl': photoUrl,
      'usn': usn,
      'phone': phone,
      'approved': approved,
    };
  }
}

