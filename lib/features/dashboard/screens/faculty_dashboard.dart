import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../timetable/screens/faculty_timetable_screen.dart';
import '../../room/screens/room_availability_screen.dart';
import '../../room/screens/reserve_room_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../students/screens/students_list_screen.dart';
import '../../announcements/announcements_screen.dart';
import '../providers/portal_providers.dart';
import 'package:lottie/lottie.dart';

class FacultyDashboard extends ConsumerWidget {
  const FacultyDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh can be added here if needed for future providers
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.98),
            surfaceTintColor: Colors.transparent,
            forceElevated: true,
            leadingWidth: 56,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              // Ensure space for back and action icons when collapsed
              titlePadding: const EdgeInsetsDirectional.only(start: 72, end: 96, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Faculty Portal'),
                  SizedBox(height: 2),
                  Text('Quick access to timetable and rooms',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.16),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                icon: const Icon(Icons.person),
              ),
              IconButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: const [
                _FacultyAISuggestions(),
                SizedBox(height: 16),
                _FacultyCampusPulse(),
                SizedBox(height: 16),
                _QuickTile(
                  title: 'My Timetable',
                  subtitle: 'View and manage your schedule',
                  icon: Icons.table_chart,
                  nav: _QuickNav.facultyTimetable,
                ),
                SizedBox(height: 12),
                _QuickTile(
                  title: 'Room Availability',
                  subtitle: 'Check free rooms',
                  icon: Icons.meeting_room,
                  nav: _QuickNav.roomAvailability,
                ),
                SizedBox(height: 12),
                _QuickTile(
                  title: 'Reserve Room',
                  subtitle: 'Book rooms for sessions',
                  icon: Icons.add_business,
                  nav: _QuickNav.reserveRoom,
                ),
                SizedBox(height: 12),
                _QuickTile(
                  title: 'Student Locator',
                  subtitle: 'Find students by USN',
                  icon: Icons.location_searching,
                  nav: _QuickNav.studentLocator,
                ),
                SizedBox(height: 12),
                _QuickTile(
                  title: 'Announcements',
                  subtitle: 'View all announcements',
                  icon: Icons.campaign,
                  nav: _QuickNav.announcements,
                ),
                SizedBox(height: 12),
                _QuickTile(
                  title: 'Students List',
                  subtitle: 'View and search all students',
                  icon: Icons.people,
                  nav: _QuickNav.studentsList,
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _FacultyAISuggestions extends ConsumerWidget {
  const _FacultyAISuggestions();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freeRooms = ref.watch(freeRoomsNowStreamProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FacultyAISuggestionHeader(),
          const SizedBox(height: 8),
          freeRooms.when(
            data: (rooms) {
              final names = rooms.take(3).map((e) => (e['name'] ?? '') as String).where((s) => s.isNotEmpty).join(', ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FacultySuggestion(text: rooms.isEmpty ? 'No free rooms now.' : 'Free now: $names'),
                  const SizedBox(height: 6),
                  const _FacultySuggestion(text: 'Tip: Move lab prep or doubt-clearing to a free room.'),
                ],
              );
            },
            loading: () => const _FacultySuggestion(text: 'Checking free rooms...'),
            error: (e, _) => _FacultySuggestion(text: 'Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _FacultyAISuggestionHeader extends StatelessWidget {
  const _FacultyAISuggestionHeader();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ],
          ),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('AI Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _FacultySuggestion extends StatelessWidget {
  const _FacultySuggestion({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.bolt, size: 18),
      const SizedBox(width: 6),
      Expanded(child: Text(text)),
    ]);
  }
}

class _FacultyCampusPulse extends ConsumerWidget {
  const _FacultyCampusPulse();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anns = ref.watch(announcementsStreamProvider);
    final events = ref.watch(upcomingEventsStreamProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome),
            SizedBox(width: 8),
            Expanded(child: Text('Campus Pulse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          anns.when(
            data: (rows) {
              final latest = rows.take(3).toList();
              if (latest.isEmpty) return const Text('📰 No new announcements');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📰 Announcements', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ...latest.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${a['title']}', overflow: TextOverflow.ellipsis),
                      )),
                ],
              );
            },
            loading: () => const Text('Loading announcements...'),
            error: (e, _) => Text('Announcements: $e'),
          ),
          const SizedBox(height: 10),
          events.when(
            data: (rows) {
              final upcoming = rows.take(3).toList();
              if (upcoming.isEmpty) return const Text('📅 No upcoming events');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📅 Trending Events', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ...upcoming.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${e['title']}', overflow: TextOverflow.ellipsis),
                      )),
                ],
              );
            },
            loading: () => const Text('Loading events...'),
            error: (e, _) => Text('Events: $e'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _FacultyLottieSafe(height: 28, width: 28, url: 'https://assets1.lottiefiles.com/packages/lf20_mY9a9W.json', fallbackIcon: Icons.tips_and_updates),
              const SizedBox(width: 8),
              const Expanded(child: Text('💡 AI Tip: Share slides before class to boost engagement.')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacultyLottieSafe extends StatelessWidget {
  const _FacultyLottieSafe({required this.height, required this.width, required this.url, required this.fallbackIcon});
  final double height;
  final double width;
  final String url;
  final IconData fallbackIcon;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Lottie.network(
        url,
        repeat: true,
        frameRate: FrameRate.max,
        errorBuilder: (context, error, stack) => Icon(fallbackIcon, size: height * 0.8, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

enum _QuickNav { facultyTimetable, roomAvailability, reserveRoom, studentLocator, announcements, studentsList }

class _QuickTile extends StatefulWidget {
  const _QuickTile({required this.title, required this.subtitle, required this.icon, required this.nav});
  final String title;
  final String subtitle;
  final IconData icon;
  final _QuickNav nav;
  
  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _pressed = false;

  void _go(BuildContext context) {
    switch (widget.nav) {
      case _QuickNav.facultyTimetable:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FacultyTimetableScreen()));
        break;
      case _QuickNav.roomAvailability:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoomAvailabilityScreen()));
        break;
      case _QuickNav.reserveRoom:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReserveRoomScreen()));
        break;
      case _QuickNav.studentLocator:
        if (!mounted) return;
        context.push('/student-locator');
        break;
      case _QuickNav.announcements:
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
        break;
      case _QuickNav.studentsList:
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentsListScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => _go(context),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(widget.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

