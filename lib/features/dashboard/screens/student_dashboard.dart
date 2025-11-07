import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/screens/profile_screen.dart';
import '../providers/portal_providers.dart';
import '../widgets/portal_card.dart';
import '../../../core/constants.dart';
import '../../timetable/screens/student_timetable_screen.dart';
import '../../chat/screens/chatbot_screen.dart';
import '../../room/screens/room_availability_screen.dart';
import '../../announcements/announcements_screen.dart';
import '../../exam/screens/exam_notifications_screen.dart';
import '../../notifications/services/notification_service.dart';
import '../../students/screens/students_list_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(_selectedDayProvider);
    final timetable = ref.watch(timetableByDayStreamProvider(selectedDay));
    final events = ref.watch(upcomingEventsStreamProvider);
    final announcements = ref.watch(announcementsStreamProvider);

    ref.listen(studentExamAllocationsProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        final prevLen = previous!.value!.length;
        final newLen = next.value!.length;
        if (newLen > prevLen) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New exam allocation available')));
          NotificationService().show(title: 'Exam Allocation', body: 'Your exam seat has been assigned.');
        }
      }
    });

    ref.listen(todaysTimetableStreamProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue) {
        if (next.value!.length != previous!.value!.length) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timetable updated')));
        }
      }
    });

    final tabIndex = ref.watch(_tabIndexProvider);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.06),
              Theme.of(context).colorScheme.secondary.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
        onRefresh: () async {
          // Refresh all stream providers
          ref.invalidate(todaysTimetableStreamProvider);
          ref.invalidate(upcomingEventsStreamProvider);
          ref.invalidate(announcementsStreamProvider);
          // Wait a bit for streams to refresh
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
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
              collapseMode: CollapseMode.pin,
              // Prevent overlap with back and action icons
              titlePadding: const EdgeInsetsDirectional.only(start: 72, end: 96, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Campus Portal'),
                  SizedBox(height: 2),
                  Text('Your day, summarized at a glance',
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
              children: [
                const _AssistantPanel(),
                const SizedBox(height: 16),
                _QuickActions(),
                const SizedBox(height: 16),
                const _AISuggestions(),
                const SizedBox(height: 16),
                const _CampusPulse(),
                const SizedBox(height: 16),
                _InteractiveScale(
                  child: _GlassCard(
                  title: "Today's Timetable",
                  icon: Icons.schedule,
                  child: timetable.when(
                    data: (rows) {
                      // Weekday selector chips
                      final dayNames = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                      final today = DateTime.now().weekday;
                      Widget chips = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: List.generate(7, (i) {
                            final day = i + 1;
                            final active = day == selectedDay;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(dayNames[i]),
                                selected: active,
                                onSelected: (_) => ref.read(_selectedDayProvider.notifier).state = day,
                                showCheckmark: false,
                                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                labelStyle: TextStyle(color: active ? Theme.of(context).colorScheme.primary : Colors.black87),
                              ),
                            );
                          }),
                        ),
                      );

                      if (rows.isEmpty) return const Text('No classes scheduled today');
                      // Determine next class for highlighted badge (only for current day)
                      int toMin(String t){final p=t.split(':');return (int.tryParse(p[0])??0)*60+(int.tryParse(p[1])??0);}                        
                      final now = DateTime.now();
                      final nowMin = now.hour*60 + now.minute;
                      final nextIndex = selectedDay == today
                        ? rows.indexWhere((e) => toMin((e['start_time'] ?? '') as String) > nowMin)
                        : -1;

                      final List<Widget> timetableChildren = [chips];
                      for (var i = 0; i < rows.length; i++) {
                        final e = rows[i];
                        final idx = i;
                          final subject = (e['subject'] ?? '') as String;
                          final room = ((e['room']) ?? '').toString();
                          final start = (e['start_time'] ?? '') as String;
                          final end = (e['end_time'] ?? '') as String;
                          final cur = now.hour*60 + now.minute;
                          final s = toMin(start);
                          final eMin = toMin(end);
                          final total = (eMin - s).clamp(1, 24*60);
                          final elapsed = (cur - s).clamp(0, total);
                          final progress = total == 0 ? 0.0 : (elapsed/total).toDouble();
                          final remaining = (eMin - cur).clamp(0, total);
                          timetableChildren.add(Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.grey.shade50,
                              border: Border.all(color: idx == nextIndex && selectedDay == today ? Theme.of(context).colorScheme.primary.withOpacity(0.6) : Colors.grey.shade200, width: idx == nextIndex && selectedDay == today ? 2 : 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 8, height: 24, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(999))),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    if (idx == nextIndex && selectedDay == today) ...[
                                      const _Badge(text: 'Next', color: Colors.orange),
                                      const SizedBox(width: 8),
                                    ],
                                    _Badge(text: '$start–$end'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.meeting_room, size: 16, color: Colors.grey.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(room.isEmpty ? 'TBD' : room, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700))),
                                    const SizedBox(width: 8),
                                    _Badge(text: remaining == 0 ? 'Done' : '${remaining}m left', color: remaining == 0 ? Colors.grey : Colors.green),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress.isNaN ? 0.0 : progress.clamp(0.0,1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.shade200,
                                  ),
                                ),
                              ],
                            ),
                          ));
                      }
                      return Column(children: timetableChildren);
                    },
                    loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
                    error: (err, st) => Text('$err'),
                  ),
                )),
                const SizedBox(height: 16),
                _GlassRow(
                  left: _InteractiveScale(child: _GlassCard(
                    title: 'Attendance',
                    icon: Icons.percent,
                    child: const Text('Attendance module coming soon'),
                  )),
                  right: _InteractiveScale(child: _GlassCard(
                    title: 'Upcoming Events',
                    icon: Icons.event,
                    child: events.when(
                      data: (rows) => rows.isEmpty
                          ? const Text('No upcoming events')
                          : Column(
                              children: rows.take(4).map((e) {
                                final start = DateTime.parse((e['start_at']).toString());
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                title: Text(
                                  (e['title'] ?? '') as String,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                subtitle: Text(
                                  '${start.toLocal()}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                );
                              }).toList(),
                            ),
                      loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
                      error: (err, st) => Text('$err'),
                    ),
                  )),
                ),
                const SizedBox(height: 16),
                _InteractiveScale(child: _GlassCard(
                  title: 'College News',
                  icon: Icons.campaign,
                  child: announcements.when(
                    data: (rows) {
                      if (rows.isEmpty) {
                        return const Text('No announcements yet');
                      }
                      
                      // Group exam allocation announcements by exam name, date, and time
                      final groupedAnnouncements = <String, List<Map<String, dynamic>>>{};
                      final otherAnnouncements = <Map<String, dynamic>>[];
                      
                      for (final e in rows) {
                        final title = (e['title'] ?? '') as String;
                        final body = ((e['body'] ?? '') as String).toString();
                        
                        if (title == 'Exam Seat Allocated') {
                          // Extract exam name, date, and time from body
                          // Format: "Exam Name: Room X, Seat Y on YYYY-MM-DD at HH:MM"
                          final match = RegExp(r'^(.+?):\s*Room\s+([^,]+),\s*Seat\s+\d+\s+on\s+(\d{4}-\d{2}-\d{2})\s+at\s+(\d{2}:\d{2})').firstMatch(body);
                          if (match != null) {
                            final examName = match.group(1)?.trim() ?? '';
                            final date = match.group(3) ?? '';
                            final time = match.group(4) ?? '';
                            final key = '$examName|$date|$time';
                            
                            if (!groupedAnnouncements.containsKey(key)) {
                              groupedAnnouncements[key] = [];
                            }
                            groupedAnnouncements[key]!.add(e);
                          } else {
                            // Try alternative format: "Exam Name: Room X, Seat Y on YYYY-MM-DD at HH:MM"
                            // Or if pattern doesn't match, treat as regular announcement
                            otherAnnouncements.add(e);
                          }
                        } else {
                          otherAnnouncements.add(e);
                        }
                      }
                      
                      // Build final list: grouped exam allocations first, then others
                      final displayList = <Map<String, dynamic>>[];
                      
                      // Add grouped exam allocations
                      for (final entry in groupedAnnouncements.entries) {
                        final parts = entry.key.split('|');
                        final examName = parts[0];
                        final date = parts[1];
                        final time = parts[2];
                        
                        // Extract all rooms from the grouped announcements
                        final rooms = <String>{};
                        for (final ann in entry.value) {
                          final body = ((ann['body'] ?? '') as String).toString();
                          final roomMatch = RegExp(r'Room\s+([^,]+)').firstMatch(body);
                          if (roomMatch != null) {
                            rooms.add(roomMatch.group(1)?.trim() ?? '');
                          }
                        }
                        
                        // Create a single grouped announcement
                        String roomText;
                        if (rooms.length == 1) {
                          roomText = rooms.first;
                        } else if (rooms.length <= 3) {
                          roomText = rooms.join(', ');
                        } else {
                          roomText = '${rooms.length} rooms';
                        }
                        
                        displayList.add({
                          'title': 'Exam Seat Allocated',
                          'body': '$examName on $date at $time in $roomText',
                          'created_at': entry.value.first['created_at'],
                          'original_id': entry.value.first['id']?.toString(), // Store first ID for deletion
                          'grouped_announcements': entry.value, // Store all grouped announcements for deletion
                        });
                      }
                      
                      // Add other announcements
                      for (final ann in otherAnnouncements) {
                        displayList.add({
                          'title': ann['title'],
                          'body': ann['body'],
                          'created_at': ann['created_at'],
                          'id': ann['id']?.toString(),
                        });
                      }
                      
                      // Sort by created_at (most recent first) and take first 3
                      displayList.sort((a, b) {
                        try {
                          return DateTime.parse((b['created_at']).toString()).compareTo(DateTime.parse((a['created_at']).toString()));
                        } catch (e) {
                          return 0;
                        }
                      });
                      
                      final user = ref.watch(portalUserProvider);
                      final isAdmin = user?.role == AppRoles.admin;
                      final deleteAnnouncement = isAdmin ? ref.watch(deleteAnnouncementProvider) : null;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: displayList.take(3).map((e) {
                          final title = (e['title'] ?? '') as String;
                          final body = ((e['body'] ?? '') as String).toString();
                          // For grouped announcements, get the first original announcement ID
                          final announcementId = e['original_id'] != null 
                              ? (e['original_id'] as String)
                              : (e['id'] ?? '').toString();
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          height: 1.4,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isAdmin && announcementId.isNotEmpty && deleteAnnouncement != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      // For grouped announcements, we need to delete all related announcements
                                      // Find all announcements with the same exam name, date, and time
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Announcement'),
                                          content: const Text('Are you sure you want to delete this announcement?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (confirm == true) {
                                        try {
                                          // If it's a grouped announcement, delete all related ones
                                          if (e['grouped_announcements'] != null) {
                                            final grouped = e['grouped_announcements'] as List;
                                            for (final ann in grouped) {
                                              final id = (ann['id'] ?? '').toString();
                                              if (id.isNotEmpty) {
                                                await deleteAnnouncement(id);
                                              }
                                            }
                                          } else {
                                            // Regular announcement, delete normally
                                            await deleteAnnouncement(announcementId);
                                          }
                                          // Invalidate the stream to refresh the UI
                                          ref.invalidate(announcementsStreamProvider);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Announcement deleted successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error deleting announcement: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
                    error: (err, st) => Text('$err'),
                  ),
                )),
                const SizedBox(height: 16),
                _InteractiveScale(child: _GlassCard(
                  title: 'Students List',
                  icon: Icons.people,
                  child: const Text('View and search all students'),
                ), onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentsListScreen()));
                }),
              ],
            ),
          ),
        ],
        ),
      ),
      ),
      bottomNavigationBar: _BottomNav(tabIndex: tabIndex),
    );
  }
}

class _GlassRow extends StatelessWidget {
  const _GlassRow({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: 16),
          right,
        ],
      );
    }
    return Row(children: [
      Expanded(child: left),
      const SizedBox(width: 16),
      Expanded(child: right),
    ]);
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AISuggestions extends StatelessWidget {
  const _AISuggestions();
  @override
  Widget build(BuildContext context) {
    return _InteractiveScale(child: _GlassCard(
      title: 'AI Suggestions',
      icon: Icons.auto_awesome,
      child: Column(
        children: [
          Row(
            children: [
              const _LottieSafe(height: 36, width: 36, url: 'https://assets1.lottiefiles.com/packages/lf20_ct8v6U.json', fallbackIcon: Icons.auto_awesome),
              const SizedBox(width: 8),
              const Expanded(child: _SuggestionRow(text: '📚 You have a 20‑min gap. Review notes for next class.')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const _LottieSafe(height: 36, width: 36, url: 'https://assets7.lottiefiles.com/packages/lf20_rKQ6LK.json', fallbackIcon: Icons.directions_walk),
              const SizedBox(width: 8),
              const Expanded(child: _SuggestionRow(text: '🚶 Traffic moderate near Block B. Leave 5 mins early.')),
            ],
          ),
        ],
      ),
    ));
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.bolt, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _ActionChip(icon: Icons.psychology_alt, label: 'Ask AI', route: 'chatbot'),
        _ActionChip(icon: Icons.schedule, label: 'My Timetable', route: 'student-timetable'),
        _ActionChip(icon: Icons.campaign, label: 'Announcements', route: 'announcements'),
        _ActionChip(icon: Icons.meeting_room, label: 'Free Rooms', route: 'rooms'),
        _ActionChip(icon: Icons.assignment_turned_in, label: 'Exam Allocations', route: 'exam-allocations'),
        _ActionChip(icon: Icons.location_searching, label: 'Student Locator', route: 'student-locator'),
        _ActionChip(icon: Icons.people, label: 'Students List', route: 'students-list'),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.route, this.hint});
  final IconData icon;
  final String label;
  final String? route;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return _InteractiveScale(
      onTap: () {
        if (hint != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint!)));
          return;
        }
        if (route == 'student-timetable') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentTimetableScreen()));
          return;
        }
        if (route == 'chatbot') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatbotScreen()));
          return;
        }
        if (route == 'rooms') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoomAvailabilityScreen()));
          return;
        }
        if (route == 'announcements') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
          return;
        }
        if (route == 'exam-allocations') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamNotificationsScreen()));
          return;
        }
        if (route == 'student-locator') {
          context.push('/student-locator');
          return;
        }
        if (route == 'students-list') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentsListScreen()));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InteractiveScale extends StatefulWidget {
  const _InteractiveScale({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<_InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<_InteractiveScale> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.98 : (_hover ? 1.01 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _AssistantPanel extends ConsumerWidget {
  const _AssistantPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(portalUserProvider);
    final timetable = ref.watch(todaysTimetableStreamProvider);
    final freeRooms = ref.watch(freeRoomsNowStreamProvider);
    final events = ref.watch(upcomingEventsStreamProvider);

    String greet() {
      final h = DateTime.now().hour;
      if (h < 12) return 'Good morning';
      if (h < 17) return 'Good afternoon';
      return 'Good evening';
    }

    return _InteractiveScale(
      child: _GlassCard(
        title: '${greet()}, ${user?.displayName ?? 'there'}',
        icon: Icons.auto_awesome,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            timetable.when(
              data: (rows) {
                String nextClass = 'No more classes today';
                if (rows.isNotEmpty) {
                  nextClass = 'Next: ${rows.first['subject']} @ ${rows.first['start_time']}';
                }
                return Text(nextClass);
              },
              loading: () => const Text('Fetching your timetable...'),
              error: (e, _) => Text('Timetable: $e'),
            ),
            const SizedBox(height: 6),
            freeRooms.when(
              data: (rooms) => Text('Free rooms now: ${rooms.length}'),
              loading: () => const Text('Checking free rooms...'),
              error: (e, _) => Text('Rooms: $e'),
            ),
            const SizedBox(height: 6),
            events.when(
              data: (rows) => Text('Upcoming events: ${rows.length}'),
              loading: () => const Text('Loading events...'),
              error: (e, _) => Text('Events: $e'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniAskChip(label: 'Where is my next class?', prompt: 'Where is my next class?'),
                _MiniAskChip(label: 'Who teaches DBMS?', prompt: 'Who teaches DBMS?'),
                _MiniAskChip(label: 'Show free rooms now', prompt: 'Which rooms are free right now?'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final _tabIndexProvider = StateProvider<int>((_) => 0);
final _selectedDayProvider = StateProvider<int>((_) => DateTime.now().weekday);

class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.tabIndex});
  final int tabIndex;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onTap(int i) {
      ref.read(_tabIndexProvider.notifier).state = i;
      if (i == 1) context.push('/chatbot');
      if (i == 2) context.push('/student-locator');
    }
    Widget item({required IconData icon, required String label, required bool active, required VoidCallback onTap}) {
      final color = active ? Theme.of(context).colorScheme.primary : Colors.grey;
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(icon, color: color),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            item(icon: Icons.home_filled, label: 'Home', active: tabIndex == 0, onTap: () => onTap(0)),
            item(icon: Icons.psychology, label: 'Ask', active: tabIndex == 1, onTap: () => onTap(1)),
            item(icon: Icons.location_searching, label: 'Locate', active: tabIndex == 2, onTap: () => onTap(2)),
          ],
        ),
      ),
    );
  }
}

class _MiniAskChip extends StatelessWidget {
  const _MiniAskChip({required this.label, required this.prompt});
  final String label;
  final String prompt;
  @override
  Widget build(BuildContext context) {
    return _InteractiveScale(
      onTap: () => context.push('/chatbot'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_alt, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).moveY(begin: 6, end: 0, duration: 180.ms);
  }
}

class _CampusPulse extends ConsumerWidget {
  const _CampusPulse();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anns = ref.watch(announcementsStreamProvider);
    final events = ref.watch(upcomingEventsStreamProvider);
    return _InteractiveScale(
      child: _GlassCard(
        title: 'Campus Pulse',
        icon: Icons.auto_awesome, // fallback icon
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                const _LottieSafe(height: 32, width: 32, url: 'https://assets1.lottiefiles.com/packages/lf20_mY9a9W.json', fallbackIcon: Icons.tips_and_updates),
                const SizedBox(width: 8),
                const Expanded(child: Text('💡 AI Tip: Review last lecture notes before your next class.')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LottieSafe extends StatelessWidget {
  const _LottieSafe({required this.height, required this.width, required this.url, required this.fallbackIcon});
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final bg = (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.12);
    final fg = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
