import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';
import '../../../core/constants.dart';

class BulkCreateProfilesScreen extends ConsumerStatefulWidget {
  const BulkCreateProfilesScreen({super.key});

  @override
  ConsumerState<BulkCreateProfilesScreen> createState() => _BulkCreateProfilesScreenState();
}

class _BulkCreateProfilesScreenState extends ConsumerState<BulkCreateProfilesScreen> {
  bool _loading = false;
  int _totalStudents = 0;
  int _studentsWithProfiles = 0;
  int _studentsNeedingProfiles = 0;
  int _created = 0;
  int _skipped = 0;
  int _errors = 0;
  List<String> _errorMessages = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _loading = true);
    try {
      final client = supabase;
      
      // Get all students
      final students = await client.from('students').select('usn, email');
      _totalStudents = students.length;
      
      // Get students with profiles
      final studentsWithProfiles = await client
          .from('profiles')
          .select('usn, email')
          .eq('role', AppRoles.student);
      
      // Count matches
      final studentUsns = students.map((s) => s['usn']?.toString() ?? '').toSet();
      final studentEmails = students.map((s) => s['email']?.toString() ?? '').toSet();
      
      int withProfiles = 0;
      for (final profile in studentsWithProfiles) {
        final profileUsn = profile['usn']?.toString() ?? '';
        final profileEmail = profile['email']?.toString() ?? '';
        if (studentUsns.contains(profileUsn) || studentEmails.contains(profileEmail)) {
          withProfiles++;
        }
      }
      
      _studentsWithProfiles = withProfiles;
      _studentsNeedingProfiles = _totalStudents - _studentsWithProfiles;
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createProfilesInBatches() async {
    if (_isCreating) return;
    
    setState(() {
      _isCreating = true;
      _created = 0;
      _skipped = 0;
      _errors = 0;
      _errorMessages = [];
    });

    try {
      final client = supabase;
      
      // Get all students without profiles
      final allStudents = await client.from('students').select();
      final existingProfiles = await client
          .from('profiles')
          .select('usn, email')
          .eq('role', AppRoles.student);
      
      final existingUsns = existingProfiles
          .map((p) => p['usn']?.toString()?.trim() ?? '')
          .where((usn) => usn.isNotEmpty)
          .toSet();
      final existingEmails = existingProfiles
          .map((p) => p['email']?.toString()?.trim() ?? '')
          .where((email) => email.isNotEmpty)
          .toSet();
      
      // Filter students without profiles
      final studentsNeedingProfiles = allStudents.where((student) {
        final usn = student['usn']?.toString()?.trim() ?? '';
        final email = student['email']?.toString()?.trim() ?? '';
        return !existingUsns.contains(usn) && !existingEmails.contains(email);
      }).toList();
      
      debugPrint('Found ${studentsNeedingProfiles.length} students needing profiles');
      
      // Process in batches of 10 (to avoid rate limits)
      const batchSize = 10;
      for (var i = 0; i < studentsNeedingProfiles.length; i += batchSize) {
        if (!mounted) break;
        
        final batch = studentsNeedingProfiles.skip(i).take(batchSize).toList();
        
        for (final student in batch) {
          if (!mounted) break;
          
          try {
            final email = student['email']?.toString()?.trim() ?? '';
            final usn = student['usn']?.toString()?.trim() ?? '';
            final name = student['name']?.toString()?.trim() ?? '';
            final phone = student['phone']?.toString()?.trim() ?? '';
            final department = student['department']?.toString()?.trim() ?? '';
            final semester = student['semester']?.toString()?.trim() ?? '';
            
            if (email.isEmpty) {
              _skipped++;
              _errorMessages.add('Skipped $usn: No email');
              continue;
            }
            
            // Check if profile already exists
            final existingProfile = await client
                .from('profiles')
                .select('id, email')
                .or('usn.eq.$usn,email.eq.$email')
                .maybeSingle();
            
            if (existingProfile != null) {
              // Profile exists, update it with student data
              await client.from('profiles').update({
                'name': name,
                'usn': usn,
                'phone': phone,
                'department': department,
                'year': int.tryParse(semester) ?? null,
              }).eq('id', existingProfile['id']);
              
              _created++;
            } else {
              // Check if auth user exists by trying to sign in (we can't list users without admin)
              // For now, we'll skip students without existing auth users
              // They need to be created using Admin API (see BULK_CREATE_PROFILES_GUIDE.md)
              _skipped++;
              _errorMessages.add('Skipped $usn: Auth user needs to be created first (use Admin API)');
            }
            
            // Update UI every 10 students
            if (_created % 10 == 0 || _skipped % 10 == 0) {
              if (mounted) {
                setState(() {});
              }
            }
            
            // Small delay to avoid rate limits
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            _errors++;
            final usn = student['usn']?.toString() ?? 'Unknown';
            _errorMessages.add('Error for $usn: ${e.toString()}');
            debugPrint('Error creating profile for ${student['usn']}: $e');
          }
        }
        
        // Delay between batches
        if (i + batchSize < studentsNeedingProfiles.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Completed! Created: $_created, Skipped: $_skipped, Errors: $_errors',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Reload statistics
        await _loadStatistics();
      }
    } catch (e) {
      debugPrint('Error creating profiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Create Student Profiles'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statistics',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _StatRow(
                            label: 'Total Students',
                            value: _totalStudents.toString(),
                            color: Colors.blue,
                          ),
                          _StatRow(
                            label: 'With Profiles',
                            value: _studentsWithProfiles.toString(),
                            color: Colors.green,
                          ),
                          _StatRow(
                            label: 'Needing Profiles',
                            value: _studentsNeedingProfiles.toString(),
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isCreating) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text('Creating profiles...'),
                            const SizedBox(height: 8),
                            Text('Created: $_created'),
                            Text('Skipped: $_skipped'),
                            Text('Errors: $_errors'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  FilledButton.icon(
                    onPressed: _isCreating ? null : _createProfilesInBatches,
                    icon: const Icon(Icons.person_add),
                    label: Text(_isCreating ? 'Creating...' : 'Create Profiles for All Students'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loadStatistics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Statistics'),
                  ),
                  if (_errorMessages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Errors & Warnings (${_errorMessages.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _errorMessages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• ${_errorMessages[index]}',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Note',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This utility creates profiles for students. However, creating auth users requires admin privileges.\n\n'
                            'For bulk creation of 500+ students, it\'s recommended to:\n'
                            '1. Use Supabase Admin API with service role key\n'
                            '2. Or run the SQL script in supabase/bulk_create_student_profiles.sql\n'
                            '3. Or create auth users manually in Supabase Dashboard',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

