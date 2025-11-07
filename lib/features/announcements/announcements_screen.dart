import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/providers/portal_providers.dart';
import '../../core/constants.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anns = ref.watch(announcementsStreamProvider);
    final user = ref.watch(portalUserProvider);
    final isAdmin = user?.role == AppRoles.admin;
    final deleteAnnouncement = ref.watch(deleteAnnouncementProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: anns.when(
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No announcements'))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = rows[i];
                  final announcementId = (e['id'] ?? '').toString();
                  
                  return ListTile(
                    title: Text((e['title'] ?? '') as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(((e['body'] ?? '') as String).toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                          )
                        : null,
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}


