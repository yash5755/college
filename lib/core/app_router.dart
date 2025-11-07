import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/dashboard/screens/admin_dashboard.dart';
import '../features/dashboard/screens/faculty_dashboard.dart';
import '../features/dashboard/screens/student_dashboard.dart';
import '../features/student_locator/screens/student_locator_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/chat/screens/chatbot_screen.dart';
import '../features/auth/screens/pending_approval_screen.dart';
import '../features/admin/screens/approvals_screen.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/exam/screens/admin_exam_allocation_screen.dart';
import '../features/admin/screens/bulk_create_profiles_screen.dart';
import 'constants.dart';
import 'demo_config.dart';

final demoRoleProvider = StateProvider<String>((_) => kDefaultDemoRole);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userDoc = ref.watch(currentUserDocProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const _Gate(),
      ),
      if (kDemoModeEnabled)
        GoRoute(
          path: '/demo-role',
          builder: (context, state) => const _DemoRolePicker(),
        ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/faculty',
        builder: (context, state) => const FacultyDashboard(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentDashboard(),
      ),
      GoRoute(
        path: '/student-locator',
        builder: (context, state) => const StudentLocatorScreen(),
      ),
      GoRoute(
        path: '/chatbot',
        builder: (context, state) => const ChatbotScreen(),
      ),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/admin-approvals',
        builder: (context, state) => const AdminApprovalsScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/admin/exam-allocation',
        builder: (context, state) => const AdminExamAllocationScreen(),
      ),
      GoRoute(
        path: '/admin/bulk-create-profiles',
        builder: (context, state) => const BulkCreateProfilesScreen(),
      ),
    ],
    redirect: (context, state) {
      // In demo mode, bypass auth redirects entirely
      if (kDemoModeEnabled) {
        return null;
      }
      final auth = authState.value;
      final isLoggedIn = auth != null;

      // If not logged in, redirect to login unless already on login/signup
      if (!isLoggedIn) {
        final isOnAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
        return isOnAuthPage ? null : '/login';
      }

      // If logged in, check user role and redirect accordingly
      // Don't redirect if user document is still loading or has errors
      if (userDoc.isLoading || userDoc.hasError) {
        return null;
      }
      
      final user = userDoc.value;
      if (user == null) {
        // User document doesn't exist - stay on current page to show error
        return null;
      }

      // If non-student and not approved, block dashboard access
      if (user.role != AppRoles.student && user.approved == false) {
        if (state.matchedLocation != '/pending') {
          return '/pending';
        }
        return null;
      }

      final currentPath = state.matchedLocation;
      // Allow-listed routes accessible without role-based redirect
      // e.g., admin can access student locator, approvals, chatbot directly from dashboard
      const allowList = ['/student-locator', '/admin-approvals', '/chatbot', '/admin/exam-allocation', '/admin/bulk-create-profiles'];
      if (allowList.contains(currentPath)) {
        return null;
      }

      switch (user.role) {
        case AppRoles.admin:
          if (currentPath != '/admin') return '/admin';
          break;
        case AppRoles.faculty:
          if (currentPath != '/faculty') return '/faculty';
          break;
        case AppRoles.student:
        default:
          if (currentPath != '/student') return '/student';
          break;
      }

      return null; // No redirect needed
    },
  );
});

class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Demo mode: immediately route to selected role's dashboard
    if (kDemoModeEnabled) {
      final role = ref.watch(demoRoleProvider);
      switch (role) {
        case AppRoles.admin:
          return const AdminDashboard();
        case AppRoles.faculty:
          return const FacultyDashboard();
        case AppRoles.student:
        default:
          return const StudentDashboard();
      }
    }

    final authState = ref.watch(authStateChangesProvider);
    final userDoc = ref.watch(currentUserDocProvider);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = authState.value;
    if (auth == null) {
      return const LoginScreen();
    }

    // Check for errors in user document loading
    if (userDoc.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error loading user data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  userDoc.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading while user document is being fetched
    if (userDoc.isLoading) {
      // Use fast one-time fetch to avoid long wait on initial realtime stream
      final once = ref.watch(currentUserDocOnceProvider);
      if (once.hasValue) {
        final user = once.value;
        if (user == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'User Profile Not Found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        switch (user.role) {
          case AppRoles.admin:
            return const AdminDashboard();
          case AppRoles.faculty:
            return const FacultyDashboard();
          case AppRoles.student:
          default:
            return const StudentDashboard();
        }
      }

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = userDoc.value;
    
    // If user document doesn't exist, show error message
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'User Profile Not Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account exists but user profile is missing. Please contact support or sign out and create a new account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    switch (user.role) {
      case AppRoles.admin:
        return const AdminDashboard();
      case AppRoles.faculty:
        return const FacultyDashboard();
      case AppRoles.student:
      default:
        return const StudentDashboard();
    }
  }
}

class _DemoRolePicker extends ConsumerWidget {
  const _DemoRolePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Demo Role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                ref.read(demoRoleProvider.notifier).state = AppRoles.admin;
                context.go('/');
              },
              child: const Text('Admin'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(demoRoleProvider.notifier).state = AppRoles.faculty;
                context.go('/');
              },
              child: const Text('Faculty'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(demoRoleProvider.notifier).state = AppRoles.student;
                context.go('/');
              },
              child: const Text('Student'),
            ),
          ],
        ),
      ),
    );
  }
}

