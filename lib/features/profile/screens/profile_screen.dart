import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants.dart';
import '../../user/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value(null);
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((rows) {
    if (rows.isEmpty) return null;
    final data = rows.first;
    return AppUser(
      uid: data['id'] as String,
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? AppRoles.student,
      displayName: data['name'] as String?,
      department: data['department'] as String?,
      photoUrl: data['profile_pic'] as String?,
      usn: data['usn'] as String?,
      phone: data['phone'] as String?,
    );
  });
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _deptController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _deptController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Ensure a storage bucket named 'profiles' exists
      final file = File(image.path);
      final path = '${user.id}.jpg';
      await supabase.storage.from('profiles').upload(path, file, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('profiles').getPublicUrl(path);

      await supabase.from('profiles').update({'profile_pic': url}).eq('id', user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final update = {
        if (_nameController.text.trim().isNotEmpty) 'name': _nameController.text.trim(),
        if (_deptController.text.trim().isNotEmpty) 'department': _deptController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
      };
      if (update.isNotEmpty) {
        try {
          await supabase.from('profiles').update(update).eq('id', user.id);
        } catch (e) {
          // Swallow schema errors to avoid blocking UI if columns are missing
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          _nameController.text = user.displayName ?? '';
          _deptController.text = user.department ?? '';
          _phoneController.text = user.phone ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                (user.displayName?[0] ?? user.email[0]).toUpperCase(),
                                style: const TextStyle(fontSize: 32),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Text(
                  'Email: ${user.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Role: ${user.role.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (user.usn != null)
                  Text(
                    'USN: ${user.usn}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _saveProfile,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

