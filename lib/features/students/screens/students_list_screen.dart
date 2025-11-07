import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';

class StudentsListScreen extends ConsumerStatefulWidget {
  const StudentsListScreen({super.key});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _loading = true;
  String _sortBy = 'name'; // name, usn, semester, section, department
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final students = await supabase.from('students').select().order('name');
      setState(() {
        _allStudents = List<Map<String, dynamic>>.from(students);
        _filteredStudents = _allStudents;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading students: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredStudents = _allStudents);
    } else {
      setState(() {
        _filteredStudents = _allStudents.where((student) {
          final usn = (student['usn']?.toString() ?? '').toLowerCase();
          final name = (student['name']?.toString() ?? '').toLowerCase();
          final email = (student['email']?.toString() ?? '').toLowerCase();
          final phone = (student['phone']?.toString() ?? '').toLowerCase();
          final department = (student['department']?.toString() ?? '').toLowerCase();
          final semester = (student['semester']?.toString() ?? '').toLowerCase();
          final section = (student['section']?.toString() ?? '').toLowerCase();
          
          return usn.contains(query) ||
              name.contains(query) ||
              email.contains(query) ||
              phone.contains(query) ||
              department.contains(query) ||
              semester.contains(query) ||
              section.contains(query);
        }).toList();
      });
    }
    _applySort();
  }

  void _applySort() {
    setState(() {
      _filteredStudents.sort((a, b) {
        int comparison = 0;
        switch (_sortBy) {
          case 'usn':
            comparison = (a['usn']?.toString() ?? '').compareTo(b['usn']?.toString() ?? '');
            break;
          case 'name':
            comparison = (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
            break;
          case 'semester':
            comparison = (a['semester']?.toString() ?? '').compareTo(b['semester']?.toString() ?? '');
            break;
          case 'section':
            comparison = (a['section']?.toString() ?? '').compareTo(b['section']?.toString() ?? '');
            break;
          case 'department':
            comparison = (a['department']?.toString() ?? '').compareTo(b['department']?.toString() ?? '');
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  void _changeSort(String newSortBy) {
    setState(() {
      if (_sortBy == newSortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = newSortBy;
        _sortAscending = true;
      }
      _applySort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by USN, name, email, phone, department, semester, section...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Sort options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Sort by: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SortChip(
                          label: 'Name',
                          selected: _sortBy == 'name',
                          ascending: _sortAscending && _sortBy == 'name',
                          onTap: () => _changeSort('name'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'USN',
                          selected: _sortBy == 'usn',
                          ascending: _sortAscending && _sortBy == 'usn',
                          onTap: () => _changeSort('usn'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Semester',
                          selected: _sortBy == 'semester',
                          ascending: _sortAscending && _sortBy == 'semester',
                          onTap: () => _changeSort('semester'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Section',
                          selected: _sortBy == 'section',
                          ascending: _sortAscending && _sortBy == 'section',
                          onTap: () => _changeSort('section'),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          label: 'Department',
                          selected: _sortBy == 'department',
                          ascending: _sortAscending && _sortBy == 'department',
                          onTap: () => _changeSort('department'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing ${_filteredStudents.length} of ${_allStudents.length} students',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Students list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No students found matching "${_searchController.text}"'
                                  : 'No students found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStudents,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    (student['name']?.toString() ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  student['name']?.toString() ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.badge,
                                      label: 'USN',
                                      value: student['usn']?.toString() ?? 'N/A',
                                    ),
                                    const SizedBox(height: 4),
                                    _InfoRow(
                                      icon: Icons.email,
                                      label: 'Email',
                                      value: student['email']?.toString() ?? 'N/A',
                                    ),
                                    const SizedBox(height: 4),
                                    _InfoRow(
                                      icon: Icons.phone,
                                      label: 'Phone',
                                      value: student['phone']?.toString() ?? 'N/A',
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _InfoChip(
                                          label: 'Dept',
                                          value: student['department']?.toString() ?? 'N/A',
                                        ),
                                        const SizedBox(width: 8),
                                        _InfoChip(
                                          label: 'Sem',
                                          value: student['semester']?.toString() ?? 'N/A',
                                        ),
                                        const SizedBox(width: 8),
                                        _InfoChip(
                                          label: 'Sec',
                                          value: student['section']?.toString() ?? 'N/A',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: false,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool ascending;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Icon(
            ascending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      labelStyle: const TextStyle(fontSize: 11),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

