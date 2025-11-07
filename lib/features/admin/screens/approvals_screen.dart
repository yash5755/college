import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';

final pendingProfilesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((rows) {
        final list = List<Map<String, dynamic>>.from(rows)
            .where((r) {
              final role = r['role']?.toString() ?? '';
              final approved = r['approved'];
              // Include faculty and admin profiles that are not approved (false or null)
              // Students are auto-approved, so we only need to approve faculty and admin
              final isFacultyOrAdmin = role == 'faculty' || role == 'admin';
              final isNotApproved = approved == false || approved == null;
              return isFacultyOrAdmin && isNotApproved;
            })
            .toList();
        // Sort by creation date (oldest first)
        list.sort((a, b) {
          final ad = DateTime.tryParse((a['created_at'])?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse((b['created_at'])?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.compareTo(bd);
        });
        return list;
      });
});

class AdminApprovalsScreen extends ConsumerWidget {
  const AdminApprovalsScreen({super.key});

  Future<void> _setApproval({required String id, required bool approved, required BuildContext context, required WidgetRef ref}) async {
    try {
      await supabase.from('profiles').update({'approved': approved}).eq('id', id);
      // Invalidate the stream to refresh the list
      ref.invalidate(pendingProfilesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approved ? 'Approved' : 'Rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingProfilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Approvals')),
      body: pendingAsync.when(
        data: (rows) {
          if (rows.isEmpty) return const Center(child: Text('No pending approvals'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final id = (r['id']).toString();
              final email = (r['email'] ?? '') as String;
              final name = (r['name'] ?? '') as String;
              final role = (r['role'] ?? '') as String;
              final dept = (r['department'] ?? '') as String;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(name.isEmpty ? email : name),
                  subtitle: Text('$role • ${dept.isEmpty ? '—' : dept}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _setApproval(id: id, approved: false, context: context, ref: ref),
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Reject',
                      ),
                      IconButton(
                        onPressed: () => _setApproval(id: id, approved: true, context: context, ref: ref),
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: 'Approve',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}


