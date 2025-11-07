import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_router.dart';
import 'core/theme.dart';
import 'core/supabase_client.dart';
import 'core/demo_config.dart';
import 'core/demo_seed.dart';
import 'features/notifications/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase backend
  await initializeSupabase();
  // Initialize local notifications
  await NotificationService().initialize();
  if (kDemoModeEnabled) {
    // Seed demo data for locator and timetable
    await seedDemoData();
  }
  runApp(const ProviderScope(child: VVCEApp()));
}

class VVCEApp extends ConsumerWidget {
  const VVCEApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VVCE College Management',
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
