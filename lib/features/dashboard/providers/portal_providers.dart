import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../../auth/providers/auth_providers.dart';
import '../../user/models/user_model.dart';
import 'dart:async';

final supabaseClientProvider = Provider<SupabaseClient>((_) => supabase);

final todayWeekdayProvider = Provider<int>((_) {
  final now = DateTime.now();
  return now.weekday; // 1 (Mon) - 7 (Sun)
});

final portalUserProvider = Provider<AppUser?>((ref) {
  final user = ref.watch(currentUserDocProvider).valueOrNull;
  return user;
});

final todaysTimetableStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(portalUserProvider);
  final weekday = ref.watch(todayWeekdayProvider);
  if (user == null) return const Stream.empty();
  // Filter in Dart to support current supabase stream API on this version
  return client
      .from('timetables')
      .stream(primaryKey: ['id'])
      .map((rows) {
    final filtered = rows.where((r) => (r['user_id']) == user.uid && (r['day_of_week']) == weekday).toList();
    filtered.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));
    return filtered;
  });
});

// Timetable by specific weekday (1=Mon..7=Sun)
final timetableByDayStreamProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, dayOfWeek) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(portalUserProvider);
  if (user == null) return const Stream.empty();
  return client
      .from('timetables')
      .stream(primaryKey: ['id'])
      .map((rows) {
    final filtered = rows.where((r) => (r['user_id']) == user.uid && (r['day_of_week']) == dayOfWeek).toList();
    filtered.sort((a, b) => (a['start_time'] as String).compareTo(b['start_time'] as String));
    return filtered;
  });
});

final announcementsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserDocProvider).valueOrNull;
  final userRole = user?.role ?? 'student';
  
  return client
      .from('announcements')
      .stream(primaryKey: ['id'])
      .map((rows) {
    // Filter announcements by audience based on user role
    final filtered = rows.where((announcement) {
      final audience = announcement['audience'];
      if (audience == null) return true; // If no audience specified, show to all
      
      // Convert audience to List if it's not already
      List<String> audienceList;
      if (audience is List) {
        audienceList = audience.map((e) => e.toString().toLowerCase()).toList();
      } else if (audience is String) {
        audienceList = [audience.toLowerCase()];
      } else {
        return true; // If can't parse, show to all
      }
      
      // Map user role to audience
      String roleAudience;
      switch (userRole) {
        case 'admin':
        case 'faculty':
          roleAudience = 'teacher';
          break;
        case 'student':
        default:
          roleAudience = 'student';
          break;
      }
      
      // Show if audience contains user's role OR contains 'all' OR is empty
      return audienceList.contains(roleAudience) || 
             audienceList.contains('all') || 
             audienceList.isEmpty;
    }).toList();
    
    final sorted = List<Map<String, dynamic>>.from(filtered)
      ..sort((a, b) {
        try {
          return DateTime.parse((b['created_at']).toString()).compareTo(DateTime.parse((a['created_at']).toString()));
        } catch (e) {
          return 0;
        }
      });
    return sorted;
  });
});

final upcomingEventsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('events')
      .stream(primaryKey: ['id'])
      .map((rows) {
    final sorted = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) {
        try {
          return DateTime.parse((a['start_at']).toString()).compareTo(DateTime.parse((b['start_at']).toString()));
        } catch (e) {
          return 0;
        }
      });
    final now = DateTime.now();
    return sorted.where((e) {
      try {
        return DateTime.parse((e['start_at']).toString()).isAfter(now.subtract(const Duration(hours: 2)));
      } catch (e) {
        return false;
      }
    }).toList();
  });
});

// -------- AI-style dynamic helpers --------

bool _isNowInRange(String start, String end) {
  int toMin(String t) { final p = t.split(':'); return int.parse(p[0]) * 60 + int.parse(p[1]); }
  final now = DateTime.now();
  final cur = now.hour * 60 + now.minute;
  final s = toMin(start);
  final e = toMin(end);
  return cur >= s && cur <= e;
}

// Stream of currently free rooms (not under maintenance, no class right now)
final freeRoomsNowStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final weekday = ref.watch(todayWeekdayProvider);

  // React to changes in both rooms and timetables, recompute on each tick (per minute)
  final roomsStream = client.from('rooms').stream(primaryKey: ['id']);
  final ttStream = client.from('timetables').stream(primaryKey: ['id']);

  // Combine latest values and recompute every 30s to catch time passing
  final controller = StreamController<List<Map<String, dynamic>>>();
  List<Map<String, dynamic>> _rooms = const [];
  List<Map<String, dynamic>> _tts = const [];

  void recompute() {
    if (_rooms.isEmpty) { controller.add(const []); return; }
    // Busy rooms now = any timetable matching day_of_week and time window
    final busyRoomIds = <String>{};
    for (final r in _tts) {
      try {
        if ((r['day_of_week']) == weekday && _isNowInRange((r['start_time'] ?? '') as String, (r['end_time'] ?? '') as String)) {
          final rid = r['room_id']?.toString();
          if (rid != null && rid.isNotEmpty) busyRoomIds.add(rid);
        }
      } catch (_) {}
    }
    final free = _rooms.where((r) => (r['is_maintenance'] == false || r['is_maintenance'] == null)
        && !busyRoomIds.contains(r['id']?.toString())).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    controller.add(free);
  }

  late final StreamSubscription roomsSub;
  late final StreamSubscription ttSub;
  Timer? ticker;

  roomsSub = roomsStream.listen((data) { _rooms = List<Map<String, dynamic>>.from(data); recompute(); });
  ttSub = ttStream.listen((data) { _tts = List<Map<String, dynamic>>.from(data); recompute(); });
  ticker = Timer.periodic(const Duration(seconds: 30), (_) => recompute());

  ref.onDispose(() {
    roomsSub.cancel();
    ttSub.cancel();
    ticker?.cancel();
    controller.close();
  });

  return controller.stream;
});

// Admin: profiles count (active users)
final profilesCountStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // Use count via channel-like approach: fallback to polling stream on profiles
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.length);
});

// Admin: helper to create announcements
final createAnnouncementProvider = Provider<Future<void> Function({required String title, String? body, List<String>? audience})>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ({required String title, String? body, List<String>? audience}) async {
    final uid = client.auth.currentUser?.id;
    await client.from('announcements').insert({
      'title': title,
      'body': body,
      if (audience != null) 'audience': audience,
      'created_by': uid,
    });
  };
});

// Admin: helper to delete announcements
final deleteAnnouncementProvider = Provider<Future<void> Function(String announcementId)>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (String announcementId) async {
    await client.from('announcements').delete().eq('id', announcementId);
  };
});

// Admin: helper to delete all announcements
final deleteAllAnnouncementsProvider = Provider<Future<void> Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () async {
    // First, fetch all announcement IDs
    final announcements = await client.from('announcements').select('id');
    
    if (announcements.isEmpty) return;
    
    // Extract all IDs
    final ids = announcements.map((a) => a['id'] as String).toList();
    
    // Delete all announcements by their IDs
    // Use 'inFilter' to delete multiple rows at once
    await client.from('announcements').delete().inFilter('id', ids);
  };
});
