import 'constants.dart';

// Toggle to enable demo mode (bypasses Firebase auth and Firestore user fetch)
const bool kDemoModeEnabled = false;

// Default role when demo mode is enabled. Can be changed at runtime via role picker.
const String kDefaultDemoRole = AppRoles.student;
