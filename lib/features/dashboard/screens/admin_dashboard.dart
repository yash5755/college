import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../room/screens/room_availability_screen.dart';
import '../../timetable/screens/admin_timetable_manage_screen.dart';
import '../../exam/screens/admin_exam_allocation_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../students/screens/students_list_screen.dart';
import '../providers/portal_providers.dart';
import '../widgets/portal_card.dart';
import '../../../core/constants.dart';
import 'package:lottie/lottie.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersCount = ref.watch(profilesCountStreamProvider);
    final announcements = ref.watch(announcementsStreamProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all stream providers
          ref.invalidate(profilesCountStreamProvider);
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
              // Add start/end padding so the title never overlaps the back button or actions
              titlePadding: const EdgeInsetsDirectional.only(start: 72, end: 96, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Portal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Manage rooms, schedules and announcements',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.18),
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
                const _AdminAISuggestions(),
                const SizedBox(height: 16),
                const _AdminCampusPulse(),
                const SizedBox(height: 16),
                _StatRow(
                  left: _StatCard(
                    title: 'Active Users',
                    icon: Icons.people,
                    child: usersCount.when(
                      data: (n) => Text(
                      '$n registered',
                      style: Theme.of(context).textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                      loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                      error: (e, _) => Text('$e'),
                    ),
                  ),
                  right: _ActionCard(
                    title: 'Manage Rooms',
                    icon: Icons.meeting_room,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RoomAvailabilityScreen()),
                    ),
                    subtitle: 'Create, edit or mark maintenance',
                  ),
                ),
                const SizedBox(height: 16),
                _StatRow(
                  left: _ActionCard(
                    title: 'Timetables',
                    icon: Icons.table_view,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminTimetableManageScreen()),
                    ),
                    subtitle: 'Manage schedules for all',
                  ),
                  right: _StatCard(
                    title: 'Announcements',
                    icon: Icons.campaign,
                    child: announcements.when(
                      data: (rows) {
                        if (rows.isEmpty) {
                          return const Text('No announcements');
                        }
                        final deleteAnnouncement = ref.watch(deleteAnnouncementProvider);
                        return Column(
                          children: rows.take(4).map((e) {
                            final announcementId = (e['id'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (e['title'] ?? '') as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          ((e['body'] ?? '') as String).toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    tooltip: 'Delete announcement',
                                    onPressed: () async {
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
                                      
                                      if (confirm == true && announcementId.isNotEmpty) {
                                        try {
                                          await deleteAnnouncement(announcementId);
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
                      loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                      error: (e, _) => Text('$e'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        announcements.when(
                          data: (rows) {
                            if (rows.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final deleteAllAnnouncements = ref.watch(deleteAllAnnouncementsProvider);
                            return TextButton.icon(
                              onPressed: () => _showDeleteAllDialog(context, ref, deleteAllAnnouncements, rows.length),
                              icon: const Icon(Icons.delete_sweep, size: 18),
                              label: const Text('Delete All'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showBroadcastSheet(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('New'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Approvals',
                  icon: Icons.verified_user,
                  onTap: () => context.push('/admin-approvals'),
                  subtitle: 'Approve or reject new registrations',
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Student Locator',
                  icon: Icons.location_searching,
                  onTap: () => context.push('/student-locator'),
                  subtitle: 'Find student current class & room by USN',
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Exam Allocation',
                  icon: Icons.assignment,
                  onTap: () => context.push('/admin/exam-allocation'),
                  subtitle: 'Allocate invigilators and rooms',
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Students List',
                  icon: Icons.people,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StudentsListScreen()),
                  ),
                  subtitle: 'View and search all students',
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  title: 'Bulk Create Profiles',
                  icon: Icons.person_add_alt_1,
                  onTap: () => context.push('/admin/bulk-create-profiles'),
                  subtitle: 'Create profiles for students from students table',
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.campaign),
        label: const Text('Broadcast'),
        onPressed: () => _showBroadcastSheet(context, ref),
      ),
    );
  }
}

class _AdminAISuggestions extends ConsumerWidget {
  const _AdminAISuggestions();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freeRooms = ref.watch(freeRoomsNowStreamProvider);
    return _CardBase(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                freeRooms.when(
                  data: (rooms) {
                    final count = rooms.length;
                    final names = rooms.take(3).map((e) => (e['name'] ?? '') as String).join(', ');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminSuggestion(text: count == 0
                          ? 'No free rooms right now.'
                          : '$count rooms free now • ${names.isEmpty ? '—' : names}'),
                        const SizedBox(height: 6),
                        const _AdminSuggestion(text: 'Tip: Convert free rooms to quiet study spaces this hour.'),
                      ],
                    );
                  },
                  loading: () => const _AdminSuggestion(text: 'Finding free rooms...'),
                  error: (e, _) => _AdminSuggestion(text: 'Could not fetch rooms: $e'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSuggestion extends StatelessWidget {
  const _AdminSuggestion({required this.text});
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

class _AdminCampusPulse extends ConsumerWidget {
  const _AdminCampusPulse();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anns = ref.watch(announcementsStreamProvider);
    final events = ref.watch(upcomingEventsStreamProvider);
    return _CardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ]),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Campus Pulse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ],
          ),
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
              const _AdminLottieSafe(height: 28, width: 28, url: 'https://assets1.lottiefiles.com/packages/lf20_mY9a9W.json', fallbackIcon: Icons.tips_and_updates),
              const SizedBox(width: 8),
              const Expanded(child: Text('💡 AI Tip: Approve room requests in off-peak times.')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminLottieSafe extends StatelessWidget {
  const _AdminLottieSafe({required this.height, required this.width, required this.url, required this.fallbackIcon});
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right});
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

class _CardBase extends StatelessWidget {
  const _CardBase({required this.child, this.trailing});
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: (cardTheme.shape is RoundedRectangleBorder)
            ? (cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(20),
        color: cardTheme.color ?? Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing!),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.icon, required this.child, this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return _CardBase(
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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

class _ActionCard extends StatefulWidget {
  const _ActionCard({required this.title, required this.icon, required this.onTap, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _CardBase(
          trailing: widget.trailing,
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
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
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

void _showDeleteAllDialog(BuildContext context, WidgetRef ref, Future<void> Function() deleteAllAnnouncements, int count) {
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete All Announcements'),
      content: Text(
        'Are you sure you want to delete all $count announcement${count != 1 ? 's' : ''}? This action cannot be undone.',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete All'),
        ),
      ],
    ),
  ).then((confirm) async {
    if (confirm == true) {
      try {
        await deleteAllAnnouncements();
        // Invalidate the stream to refresh the UI
        ref.invalidate(announcementsStreamProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('All $count announcement${count != 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting announcements: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  });
}

void _showBroadcastSheet(BuildContext context, WidgetRef ref) {
  final create = ref.read(createAnnouncementProvider);
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final audiences = {
    'student': true,
    'teacher': true,
    'admin': true,
  };
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Broadcast Announcement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: 'Body'), maxLines: 3),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilterChip(label: const Text('Students'), selected: audiences['student']!, onSelected: (v) => audiences['student'] = v),
            FilterChip(label: const Text('Teachers'), selected: audiences['teacher']!, onSelected: (v) => audiences['teacher'] = v),
            FilterChip(label: const Text('Admins'), selected: audiences['admin']!, onSelected: (v) => audiences['admin'] = v),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Broadcast'),
            onPressed: () async {
              final audience = audiences.entries.where((e) => e.value).map((e) => e.key).toList();
              await create(title: titleCtrl.text.trim(), body: bodyCtrl.text.trim(), audience: audience);
              if (context.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement sent')));
              }
            },
          ),
        ],
      ),
    ),
  );
}

