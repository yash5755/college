import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/constants.dart';
import '../models/exam_model.dart';
import '../../user/models/user_model.dart';
import '../../../core/supabase_client.dart';
import '../../../core/ai_allocation_service.dart';
import '../../notifications/services/notification_service.dart';
import '../widgets/room_selection_dialog.dart';
import '../widgets/seat_map_widget.dart';
import '../services/seat_map_pdf_service.dart';

class AdminExamAllocationScreen extends ConsumerStatefulWidget {
  const AdminExamAllocationScreen({super.key});

  @override
  ConsumerState<AdminExamAllocationScreen> createState() => _AdminExamAllocationScreenState();
}

class _AdminExamAllocationScreenState extends ConsumerState<AdminExamAllocationScreen> {
  bool _loading = false;
  bool _showPreview = false;
  final _examNameCtrl = TextEditingController(text: 'End Semester Exam');
  final _examTimeCtrl = TextEditingController(text: '09:00');
  final _seatsPerBenchCtrl = TextEditingController(text: '2');
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));
  int _seatsPerBench = 2;
  List<_CsvStudent> _csvStudents = const [];
  String? _csvSummary;
  bool _sendNotifications = true;
  bool _isProcessingCsv = false; // Flag to prevent navigation during CSV processing
  
  AllocationResult? _lastAllocationResult;
  List<String> _selectedRoomIds = [];
  Map<String, Map<String, dynamic>> _roomLayouts = {}; // roomId -> {rows, seats_per_row}
  List<String> _selectedSections = []; // Selected sections for allocation
  bool _useSectionSelection = false; // Toggle between CSV and section selection
  List<Map<String, dynamic>> _studentsList = []; // List of students from selected sections
  List<String> _skippedStudents = []; // Students skipped due to missing profiles

  @override
  void dispose() {
    _examNameCtrl.dispose();
    _examTimeCtrl.dispose();
    _seatsPerBenchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCsv() async {
    if (!mounted || _isProcessingCsv) return;
    
    // Set processing flag to prevent any navigation
    _isProcessingCsv = true;
    
    try {
      if (!mounted) return;
      
      setState(() { 
        _loading = true; 
        _csvSummary = null; 
        _csvStudents = const []; 
      });
      
      if (!mounted) {
        _isProcessingCsv = false;
        return;
      }
      
      // Store context reference to prevent issues
      final currentContext = context;
      
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, 
        allowedExtensions: ['csv'],
        withData: true, // Try to get bytes directly
        withReadStream: false,
      );
      
      // Check if widget is still mounted and context is still valid
      if (!mounted || !currentContext.mounted) {
        _isProcessingCsv = false;
        debugPrint('Context lost after file picker');
        return;
      }
      
      if (res == null || res.files.isEmpty) {
        _isProcessingCsv = false;
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      
      if (!mounted) return;
      
      final file = res.files.first;
      List<int> bytes;
      
      // Try to get bytes directly, or read from file path
      try {
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          bytes = file.bytes!;
        } else if (file.path != null && file.path!.isNotEmpty) {
          // Read from file path (common on mobile platforms)
          if (!mounted) return;
          final fileObj = File(file.path!);
          if (!await fileObj.exists()) {
            throw Exception('CSV file not found. Please try selecting the file again.');
          }
          if (!mounted) return;
          bytes = await fileObj.readAsBytes();
          if (bytes.isEmpty) {
            throw Exception('CSV file is empty or could not be read.');
          }
        } else {
          throw Exception('Could not read CSV file. Please ensure the file is accessible and try again.');
        }
      } catch (e) {
        if (!mounted) return;
        if (e is Exception) rethrow;
        throw Exception('Error reading CSV file: $e');
      }
      
      if (!mounted) return;
      
      // Decode with UTF-8 and remove BOM if present
      String content = utf8.decode(bytes);
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }
      
      // Normalize line endings and trim
      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
      if (content.isEmpty) throw Exception('CSV file is empty');
      
      // Parse CSV - try with different configurations
      List<List<dynamic>> rows;
      try {
        rows = const CsvToListConverter().convert(content, eol: '\n');
      } catch (e) {
        // Fallback: try with default settings
        rows = const CsvToListConverter().convert(content);
      }
      
      if (rows.isEmpty) throw Exception('CSV is empty or could not be parsed');
      
      // Expect headers: usn,name,semester,section
      final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      int usnIdx = header.indexOf('usn');
      int nameIdx = header.indexOf('name');
      int semIdx = header.indexOf('semester');
      int secIdx = header.indexOf('section');
      
      if (usnIdx < 0 || nameIdx < 0) {
        throw Exception('CSV must include headers: usn,name[,semester,section]\nFound headers: ${header.join(", ")}');
      }
      
      final parsed = <_CsvStudent>[];
      int skippedRows = 0;
      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        if (r.isEmpty || r.every((cell) => cell.toString().trim().isEmpty)) {
          skippedRows++;
          continue;
        }
        
        final usn = r.length > usnIdx ? r[usnIdx].toString().trim() : '';
        final name = r.length > nameIdx ? r[nameIdx].toString().trim() : '';
        
        // Skip rows with empty USN or name
        if (usn.isEmpty || name.isEmpty) {
          skippedRows++;
          continue;
        }
        
        parsed.add(_CsvStudent(
          usn: usn,
          name: name,
          semester: semIdx >= 0 && r.length > semIdx ? r[semIdx].toString().trim() : '',
          section: secIdx >= 0 && r.length > secIdx ? r[secIdx].toString().trim() : '',
        ));
      }
      
      if (parsed.isEmpty) {
        throw Exception('No valid student records found in CSV. Please check that USN and Name columns have data.');
      }
      
      // Small delay to ensure file picker is fully closed (especially on mobile)
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Only update state if widget is still mounted
      if (!mounted) {
        debugPrint('Widget not mounted after CSV upload delay');
        _isProcessingCsv = false;
        return;
      }
      
      // Get fresh context reference
      final updateContext = context;
      if (!updateContext.mounted) {
        debugPrint('Context not mounted after delay');
        _isProcessingCsv = false;
        return;
      }
      
      // Safely update state - wrap in try-catch to prevent any exceptions
      try {
        if (!mounted || !updateContext.mounted) {
          _isProcessingCsv = false;
          return;
        }
        
        // Use SchedulerBinding to ensure we're in a safe frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isProcessingCsv) {
            // This should not happen, but just in case
            return;
          }
        });
        
        setState(() {
          _csvStudents = parsed;
          _csvSummary = 'Loaded ${parsed.length} students from CSV${skippedRows > 0 ? " (${skippedRows} empty rows skipped)" : ""}';
          _loading = false;
        });
        
        // Clear flag after state update
        _isProcessingCsv = false;
        
        // Show success message after a brief delay to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted && updateContext.mounted) {
          ScaffoldMessenger.of(updateContext).showSnackBar(
            SnackBar(
              content: Text('Successfully loaded ${parsed.length} students from CSV'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (stateError, stackTrace) {
        debugPrint('Error updating state after CSV upload: $stateError');
        debugPrint('Stack trace: $stackTrace');
        _isProcessingCsv = false; // Clear flag even on error
        if (mounted) {
          setState(() {
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV loaded successfully but there was an error updating the UI. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      // Log the error for debugging
      debugPrint('CSV upload error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      _isProcessingCsv = false; // Always clear flag on error
      
      if (!mounted) return;
      
      setState(() {
        _loading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      // Ensure flag is always cleared
      _isProcessingCsv = false;
    }
  }

  Future<void> _autoAllocate() async {
    setState(() { _loading = true; _showPreview = false; });
    try {
      final client = supabase;
      final studentsRows = await client.from('profiles').select().eq('role', AppRoles.student);
      final roomsRows = await client.from('rooms').select().eq('is_maintenance', false);
      final facultyRows = await client.from('profiles')
          .select('id, name, department')
          .inFilter('role', ['faculty', 'admin']);

      if (roomsRows.isEmpty) {
        throw Exception('No available rooms');
      }

      // Use heuristic allocation
      final result = aiExamAllocationService.heuristicPlan(
        students: studentsRows,
        rooms: roomsRows,
        faculty: facultyRows,
        examName: _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim(),
        examDate: _examDate,
        examTime: _examTimeCtrl.text.trim().isEmpty ? '09:00' : _examTimeCtrl.text.trim(),
        subject: _examNameCtrl.text.trim(),
      );

      await _saveAndNotify(result);
      if (!mounted) return;
      setState(() {
        _lastAllocationResult = result;
        _showPreview = true;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Auto allocation error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _aiAllocate() async {
    if (_selectedRoomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select rooms first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() { _loading = true; _showPreview = false; });
    try {
      final csvData = _csvStudents.isNotEmpty
          ? _csvStudents.map((s) => {
              'usn': s.usn,
              'name': s.name,
              'semester': s.semester,
              'section': s.section,
            }).toList()
          : null;

      final result = await aiExamAllocationService.generateAllocations(
        examName: _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim(),
        examDate: _examDate,
        examTime: _examTimeCtrl.text.trim().isEmpty ? '09:00' : _examTimeCtrl.text.trim(),
        subject: _examNameCtrl.text.trim(),
        csvStudents: csvData,
        selectedRoomIds: _selectedRoomIds.isNotEmpty ? _selectedRoomIds : null,
      );

      if (result.allocations.isEmpty) {
        throw Exception('No allocations produced');
      }

      await _saveAndNotify(result);
      if (!mounted) return;
      setState(() {
        _lastAllocationResult = result;
        _showPreview = true;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('AI allocation error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Allocation Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectRooms() async {
    try {
      final client = supabase;
      final rooms = await client.from('rooms').select().eq('is_maintenance', false);
      
      if (rooms.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No available rooms found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (ctx) => RoomSelectionDialog(
          availableRooms: rooms,
          selectedRoomIds: _selectedRoomIds,
          onConfirm: (selectedIds, layouts) {
            setState(() {
              _selectedRoomIds = selectedIds;
              _roomLayouts = layouts;
            });
          },
        ),
      );
    } catch (e) {
      debugPrint('Error selecting rooms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading rooms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudentsForSections(List<String> sections) async {
    try {
      final client = supabase;
      final allStudentsFromDB = <Map<String, dynamic>>[];
      final skippedStudents = <String>[];
      
      for (final sectionKey in sections) {
        final parts = sectionKey.split('-');
        if (parts.length != 2) continue;
        final sem = parts[0].trim();
        final sec = parts[1].trim();
        
        // Query students table
        final allStudentsData = await client.from('students').select();
        final students = allStudentsData.where((s) {
          final sSem = (s['semester']?.toString() ?? '').trim();
          final sSec = (s['section']?.toString() ?? '').trim();
          return sSem == sem && sSec == sec;
        }).toList();
        
        // Get USNs and fetch profiles
        final usns = students.map((s) => s['usn']?.toString()?.trim()).where((usn) => usn != null && usn.isNotEmpty).toList();
        final profiles = <String, Map<String, dynamic>>{};
        
        if (usns.isNotEmpty) {
          final profilesData = await client.from('profiles')
              .select('id, usn, name, email, role')
              .inFilter('usn', usns)
              .eq('role', AppRoles.student);
          
          for (final profile in profilesData) {
            final profileUsn = profile['usn']?.toString()?.trim();
            if (profileUsn != null && profileUsn.isNotEmpty) {
              profiles[profileUsn] = profile;
            }
          }
        }
        
        // Add all students to list, track skipped ones
        for (final student in students) {
          final studentUsn = student['usn']?.toString()?.trim() ?? '';
          allStudentsFromDB.add({
            'usn': studentUsn,
            'name': student['name']?.toString() ?? '',
            'email': student['email']?.toString() ?? '',
            'phone': student['phone']?.toString() ?? '',
            'department': student['department']?.toString() ?? '',
            'semester': sem,
            'section': sec,
          });
          
          if (!profiles.containsKey(studentUsn)) {
            skippedStudents.add('$studentUsn - ${student['name']?.toString() ?? "Unknown"}');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _studentsList = allStudentsFromDB;
          _skippedStudents = skippedStudents;
        });
      }
    } catch (e) {
      debugPrint('Error loading students for sections: $e');
    }
  }

  Future<void> _selectSections() async {
    try {
      final client = supabase;
      // Query from students table instead of profiles
      final students = await client.from('students').select('semester, section');
      
      // Get unique semester-section combinations
      final sections = <String>{};
      for (final s in students) {
        final sem = s['semester']?.toString() ?? '';
        final sec = s['section']?.toString() ?? '';
        if (sem.isNotEmpty && sec.isNotEmpty) {
          sections.add('$sem-$sec');
        }
      }
      
      final sortedSections = sections.toList()..sort();
      
      if (sortedSections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No sections found in database'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      if (!mounted) return;
      
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (ctx) => _SectionSelectionDialog(
          sections: sortedSections,
          selectedSections: _selectedSections.toSet(),
        ),
      );
      
      if (selected != null && mounted) {
        setState(() {
          _selectedSections = selected.toList()..sort();
          _studentsList = []; // Clear previous list
          _skippedStudents = []; // Clear skipped students
        });
        
        // Load students list for selected sections
        if (selected.isNotEmpty) {
          _loadStudentsForSections(selected.toList());
        }
      }
    } catch (e) {
      debugPrint('Error selecting sections: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sections: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _allocateBySection() async {
    if (_selectedSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select sections first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_selectedRoomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select rooms first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() { _loading = true; _showPreview = false; });
    try {
      final client = supabase;
      
      // Fetch students from selected sections using students table
      final allStudents = <Map<String, dynamic>>[];
      final allStudentsFromDB = <Map<String, dynamic>>[]; // Keep track of ALL students for display
      final skippedStudents = <String>[]; // Track skipped students
      final selectedSectionKeys = <String>{}; // Track selected sections for validation
      
      for (final sectionKey in _selectedSections) {
        final parts = sectionKey.split('-');
        if (parts.length != 2) continue;
        final sem = parts[0].trim();
        final sec = parts[1].trim();
        selectedSectionKeys.add('$sem-$sec');
        
        debugPrint('Fetching students for semester: "$sem", section: "$sec"');
        
        // Query with case-insensitive matching and trim
        final allStudentsData = await client.from('students').select();
        final students = allStudentsData.where((s) {
          final sSem = (s['semester']?.toString() ?? '').trim();
          final sSec = (s['section']?.toString() ?? '').trim();
          return sSem == sem && sSec == sec;
        }).toList();
        
        debugPrint('Found ${students.length} students for $sem-$sec');
        if (students.isNotEmpty) {
          debugPrint('Sample student: USN=${students.first['usn']}, Name=${students.first['name']}, Semester=${students.first['semester']}, Section=${students.first['section']}');
        }
        
        // Map students table data to expected format and validate
        // First, get all USNs from students table
        final usns = students.map((s) => s['usn']?.toString()?.trim()).where((usn) => usn != null && usn.isNotEmpty).toList();
        
        // Fetch corresponding profiles using USN to get the correct profiles.id
        final profiles = <String, Map<String, dynamic>>{};
        if (usns.isNotEmpty) {
          final profilesData = await client.from('profiles')
              .select('id, usn, name, email, role')
              .inFilter('usn', usns)
              .eq('role', AppRoles.student);
          
          for (final profile in profilesData) {
            final profileUsn = profile['usn']?.toString()?.trim();
            if (profileUsn != null && profileUsn.isNotEmpty) {
              profiles[profileUsn] = profile;
            }
          }
        }
        
        debugPrint('Matched ${profiles.length} profiles out of ${students.length} students');
        
        for (final student in students) {
          final studentSem = student['semester']?.toString()?.trim() ?? '';
          final studentSec = student['section']?.toString()?.trim() ?? '';
          final studentKey = '$studentSem-$studentSec';
          final studentUsn = student['usn']?.toString()?.trim() ?? '';
          
          // Double-check that student belongs to selected section
          if (selectedSectionKeys.contains(studentKey)) {
            // Add to all students list for display (even if no profile)
            allStudentsFromDB.add({
              'usn': studentUsn,
              'name': student['name']?.toString() ?? '',
              'email': student['email']?.toString() ?? '',
              'phone': student['phone']?.toString() ?? '',
              'department': student['department']?.toString() ?? '',
              'semester': studentSem,
              'section': studentSec,
            });
            
            // Find matching profile by USN
            final profile = profiles[studentUsn];
            if (profile == null) {
              debugPrint('Warning: No profile found for student USN: $studentUsn. Skipping this student.');
              skippedStudents.add('$studentUsn - ${student['name']?.toString() ?? "Unknown"}');
              continue;
            }
            
            // Use profiles.id (UUID) instead of students.id
            final profileId = profile['id'];
            if (profileId == null) {
              debugPrint('ERROR: Profile found but id is null for USN: $studentUsn');
              skippedStudents.add('$studentUsn - ${student['name']?.toString() ?? "Unknown"}');
              continue;
            }
            
            final profileIdStr = profileId.toString().trim();
            if (profileIdStr.isEmpty) {
              debugPrint('ERROR: Profile id is empty for USN: $studentUsn');
              skippedStudents.add('$studentUsn - ${student['name']?.toString() ?? "Unknown"}');
              continue;
            }
            
            debugPrint('Mapped student USN: $studentUsn -> Profile ID: $profileIdStr');
            
            allStudents.add({
              'id': profileIdStr, // Use profiles.id (UUID that exists in profiles table)
              'usn': studentUsn,
              'name': student['name']?.toString() ?? profile['name']?.toString() ?? '',
              'email': student['email']?.toString() ?? profile['email']?.toString() ?? '',
              'phone': student['phone']?.toString() ?? '',
              'department': student['department']?.toString() ?? '',
              'semester': studentSem,
              'section': studentSec,
            });
          } else {
            debugPrint('Warning: Student ${student['usn']} ($studentKey) does not match selected sections');
          }
        }
      }
      
      debugPrint('Total students to allocate: ${allStudents.length}');
      debugPrint('Total students found: ${allStudentsFromDB.length}');
      debugPrint('Skipped students (no profile): ${skippedStudents.length}');
      debugPrint('Selected sections: ${_selectedSections.join(", ")}');
      
      // Update state to show students list
      if (mounted) {
        setState(() {
          _studentsList = allStudentsFromDB;
          _skippedStudents = skippedStudents;
        });
      }
      
      if (allStudents.isEmpty) {
        final errorMsg = skippedStudents.isNotEmpty
            ? 'No students found with profiles in selected sections: ${_selectedSections.join(", ")}. ${skippedStudents.length} students skipped (no profile found).'
            : 'No students found in selected sections: ${_selectedSections.join(", ")}';
        throw Exception(errorMsg);
      }
      
      // Show warning if some students were skipped
      if (skippedStudents.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${skippedStudents.length} student(s) skipped (no profile found). ${allStudents.length} student(s) will be allocated.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Fetch selected rooms
      final rooms = await client.from('rooms')
          .select()
          .eq('is_maintenance', false)
          .inFilter('id', _selectedRoomIds);
      
      if (rooms.isEmpty) {
        throw Exception('Selected rooms not found');
      }
      
      // Use new seating arrangement: 3 columns, 6 benches per column, 2-3 per bench
      final result = await _allocateWithSeatingArrangement(
        students: allStudents,
        rooms: rooms,
        examName: _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim(),
        examDate: _examDate,
        examTime: _examTimeCtrl.text.trim().isEmpty ? '09:00' : _examTimeCtrl.text.trim(),
      );

      await _saveAndNotify(result);
      if (!mounted) return;
      setState(() {
        _lastAllocationResult = result;
        _showPreview = true;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Section allocation error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Allocation failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<AllocationResult> _allocateWithSeatingArrangement({
    required List<dynamic> students,
    required List<dynamic> rooms,
    required String examName,
    required DateTime examDate,
    required String examTime,
  }) async {
    // Final validation: Ensure all students are from selected sections
    if (_useSectionSelection && _selectedSections.isNotEmpty) {
      final selectedSectionKeys = _selectedSections.map((s) {
        final parts = s.split('-');
        if (parts.length == 2) {
          return '${parts[0].trim()}-${parts[1].trim()}';
        }
        return s;
      }).toSet();
      
      final validStudents = <Map<String, dynamic>>[];
      for (final student in students) {
        final sem = (student['semester']?.toString() ?? '').trim();
        final sec = (student['section']?.toString() ?? '').trim();
        final studentKey = '$sem-$sec';
        
        if (selectedSectionKeys.contains(studentKey)) {
          validStudents.add(student);
        } else {
          debugPrint('ERROR: Student ${student['usn']} ($studentKey) is NOT in selected sections: ${selectedSectionKeys.join(", ")}');
        }
      }
      
      if (validStudents.length != students.length) {
        debugPrint('WARNING: Filtered out ${students.length - validStudents.length} students not in selected sections');
      }
      
      // Replace students list with validated list
      students = validStudents;
      
      if (students.isEmpty) {
        throw Exception('No valid students found in selected sections: ${_selectedSections.join(", ")}');
      }
    }
    
    // Seating arrangement: 3 columns, 6 benches per column, 2-3 students per bench
    const int columnsPerRoom = 3;
    const int benchesPerColumn = 6;
    final int studentsPerBench = _seatsPerBench; // 2 or 3
    final int totalSeatsPerRoom = columnsPerRoom * benchesPerColumn * studentsPerBench;
    
    final allocations = <Map<String, dynamic>>[];
    final roomAssignments = <String, List<dynamic>>{};
    final examId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Track room usage
    final roomSeatCounts = <String, int>{};
    for (final room in rooms) {
      roomSeatCounts[room['id'].toString()] = 0;
    }
    
    // Shuffle students for random distribution
    final shuffledStudents = List<Map<String, dynamic>>.from(students)..shuffle();
    
    debugPrint('Allocating ${shuffledStudents.length} students to ${rooms.length} rooms');
    
    // Track seating position per room
    final roomSeatingState = <String, Map<String, int>>{};
    for (final room in rooms) {
      roomSeatingState[room['id'].toString()] = {
        'column': 1,
        'bench': 1,
        'seat': 1,
      };
    }
    
    var currentRoomIndex = 0;
    
    for (final student in shuffledStudents) {
      // Find a room with available space
      Map<String, dynamic>? selectedRoom;
      int? selectedRoomIndex;
      
      for (var attempt = 0; attempt < rooms.length; attempt++) {
        final roomIndex = (currentRoomIndex + attempt) % rooms.length;
        final room = rooms[roomIndex];
        final roomId = room['id'].toString();
        final currentSeats = roomSeatCounts[roomId] ?? 0;
        
        if (currentSeats < totalSeatsPerRoom) {
          selectedRoom = room;
          selectedRoomIndex = roomIndex;
          break;
        }
      }
      
      if (selectedRoom == null) {
        final totalCapacity = rooms.fold<int>(0, (sum, r) => sum + totalSeatsPerRoom);
        throw Exception('Not enough room capacity. Total students: ${students.length}, Total capacity: $totalCapacity');
      }
      
      final roomId = selectedRoom['id'].toString();
      final seatingState = roomSeatingState[roomId]!;
      
      // Get current position in this room
      final currentColumn = seatingState['column']!;
      final currentBench = seatingState['bench']!;
      final currentSeatInBench = seatingState['seat']!;
      
      // Calculate seat number: Column-Bench-Seat format (e.g., C1-B1-S1)
      final seatNumber = 'C$currentColumn-B$currentBench-S$currentSeatInBench';
      
      allocations.add({
        'exam_id': examId,
        'student_id': student['id'].toString(),
        'student_usn': student['usn']?.toString() ?? '',
        'student_name': student['name']?.toString() ?? student['email']?.toString() ?? '',
        'room_id': roomId,
        'room_name': selectedRoom['name']?.toString() ?? '',
        'seat_number': seatNumber,
        'exam_date': examDate.toIso8601String(),
        'exam_time': examTime,
        'subject': examName,
        'semester': student['semester']?.toString() ?? student['year']?.toString() ?? '',
        'section': student['section']?.toString() ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      roomAssignments.putIfAbsent(roomId, () => []).add(allocations.last);
      roomSeatCounts[roomId] = (roomSeatCounts[roomId] ?? 0) + 1;
      
      // Move to next seat in current room
      var nextSeat = currentSeatInBench + 1;
      var nextBench = currentBench;
      var nextColumn = currentColumn;
      
      if (nextSeat > studentsPerBench) {
        nextSeat = 1;
        nextBench++;
        if (nextBench > benchesPerColumn) {
          nextBench = 1;
          nextColumn++;
          if (nextColumn > columnsPerRoom) {
            // Room is full, reset and move to next room
            nextColumn = 1;
            nextBench = 1;
            nextSeat = 1;
            currentRoomIndex = (selectedRoomIndex! + 1) % rooms.length;
          }
        }
      }
      
      // Update seating state for this room
      seatingState['column'] = nextColumn;
      seatingState['bench'] = nextBench;
      seatingState['seat'] = nextSeat;
      
      // If room is full, move to next room for next student
      if (roomSeatCounts[roomId]! >= totalSeatsPerRoom) {
        currentRoomIndex = (selectedRoomIndex! + 1) % rooms.length;
      }
    }
    
    // Assign invigilators
    final faculty = await supabase.from('profiles')
        .select('id, name, department')
        .inFilter('role', ['faculty', 'admin']);
    
    final invigilators = <Map<String, dynamic>>[];
    final assignedFaculty = <String>{};
    var facultyIndex = 0;
    
    for (final roomId in roomAssignments.keys) {
      final studentsInRoom = roomAssignments[roomId]!.length;
      final invigilatorsNeeded = (studentsInRoom / 35).ceil().clamp(1, 3);
      final room = rooms.firstWhere((r) => r['id'].toString() == roomId);
      final roomName = room['name']?.toString() ?? '';
      
      for (var i = 0; i < invigilatorsNeeded && facultyIndex < faculty.length; i++) {
        var attempts = 0;
        while (attempts < faculty.length && assignedFaculty.contains(faculty[facultyIndex % faculty.length]['id'].toString())) {
          facultyIndex++;
          attempts++;
        }
        
        if (attempts < faculty.length) {
          final fac = faculty[facultyIndex % faculty.length];
          final facId = fac['id'].toString();
          assignedFaculty.add(facId);
          
          invigilators.add({
            'faculty_id': facId,
            'faculty_name': fac['name']?.toString() ?? '',
            'room_id': roomId,
            'room_name': roomName,
            'exam_date': examDate.toIso8601String(),
            'exam_time': examTime,
            'exam_name': examName,
          });
          facultyIndex++;
        }
      }
    }
    
    // Calculate summary
    final roomUtilization = <String, Map<String, dynamic>>{};
    roomAssignments.forEach((roomId, students) {
      final room = rooms.firstWhere((r) => r['id'].toString() == roomId);
      final used = students.length;
      roomUtilization[roomId] = {
        'room_name': room['name']?.toString() ?? '',
        'capacity': totalSeatsPerRoom,
        'used': used,
        'utilization': ((used / totalSeatsPerRoom) * 100).toStringAsFixed(1),
      };
    });
    
    return AllocationResult(
      allocations: allocations,
      invigilators: invigilators,
      summary: {
        'total_students': allocations.length,
        'total_rooms': roomAssignments.length,
        'total_invigilators': invigilators.length,
        'room_utilization': roomUtilization,
      },
    );
  }

  Future<void> _allocateFromCsv() async {
    if (_csvStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload CSV first'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (_selectedRoomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select rooms first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() { _loading = true; _showPreview = false; });
    try {
      final csvData = _csvStudents.map((s) => {
        'usn': s.usn,
        'name': s.name,
        'semester': s.semester,
        'section': s.section,
      }).toList();

      final result = await aiExamAllocationService.generateAllocations(
        examName: _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim(),
        examDate: _examDate,
        examTime: _examTimeCtrl.text.trim().isEmpty ? '09:00' : _examTimeCtrl.text.trim(),
        subject: _examNameCtrl.text.trim(),
        csvStudents: csvData,
        selectedRoomIds: _selectedRoomIds.isNotEmpty ? _selectedRoomIds : null,
      );

      await _saveAndNotify(result);
      if (!mounted) return;
      setState(() {
        _lastAllocationResult = result;
        _showPreview = true;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('CSV allocation error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Allocation failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveAndNotify(AllocationResult result) async {
    if (!mounted) return;
    
    final client = supabase;
    final examId = DateTime.now().millisecondsSinceEpoch.toString();
    final examName = _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim();
    final examTime = _examTimeCtrl.text.trim().isEmpty ? '09:00' : _examTimeCtrl.text.trim();

    // Validate room capacities before saving
    final roomCounts = <String, int>{};
    final roomCapacities = <String, int>{};
    final rooms = await client.from('rooms').select('id, capacity');
    for (final room in rooms) {
      roomCapacities[room['id'].toString()] = room['capacity'] as int? ?? 40;
    }

    for (final alloc in result.allocations) {
      final roomId = alloc['room_id']?.toString() ?? '';
      roomCounts[roomId] = (roomCounts[roomId] ?? 0) + 1;
    }

    final overCapacity = <String>[];
    roomCounts.forEach((roomId, count) {
      final capacity = roomCapacities[roomId] ?? 0;
      if (count > capacity) {
        overCapacity.add('Room $roomId: $count/$capacity');
      }
    });

    if (overCapacity.isNotEmpty) {
      throw Exception('Room capacity exceeded: ${overCapacity.join(", ")}');
    }

    // Check for duplicate student allocations before saving
    final studentAllocations = <String, Map<String, dynamic>>{};
    final studentIds = <String>{};
    for (final alloc in result.allocations) {
      final studentId = alloc['student_id']?.toString()?.trim() ?? '';
      if (studentId.isEmpty) {
        debugPrint('Warning: Skipping allocation with empty student_id');
        continue;
      }
      
      // If student already has an allocation, keep the first one and log a warning
      if (studentAllocations.containsKey(studentId)) {
        debugPrint('Warning: Student $studentId has multiple allocations. Keeping first one.');
        continue;
      }
      studentAllocations[studentId] = alloc;
      studentIds.add(studentId);
    }
    
    // Validate that all student_ids exist in profiles table before inserting
    if (studentIds.isNotEmpty) {
      debugPrint('Validating ${studentIds.length} student IDs exist in profiles table...');
      final existingProfiles = await client.from('profiles')
          .select('id')
          .inFilter('id', studentIds.toList());
      
      final existingProfileIds = existingProfiles.map((p) => p['id']?.toString()?.trim() ?? '').where((id) => id.isNotEmpty).toSet();
      final missingIds = studentIds.where((id) => !existingProfileIds.contains(id)).toList();
      
      if (missingIds.isNotEmpty) {
        debugPrint('ERROR: ${missingIds.length} student IDs not found in profiles table:');
        for (final missingId in missingIds.take(10)) {
          debugPrint('  - Missing student_id: $missingId');
        }
        throw Exception('${missingIds.length} student(s) not found in profiles table. Please ensure all students have profiles. Missing IDs: ${missingIds.take(5).join(", ")}');
      }
      
      debugPrint('✓ All ${studentIds.length} student IDs validated in profiles table');
    }
    
    // Store individual allocation records (matching schema from reset_database.sql)
    // Only insert unique student allocations with validated student_ids
    final allocationsToInsert = studentAllocations.values.where((a) {
      final studentId = a['student_id']?.toString()?.trim() ?? '';
      return studentId.isNotEmpty;
    }).map((a) {
      final studentId = a['student_id']?.toString()?.trim() ?? '';
      return {
        'exam_id': examId,
        'student_id': studentId, // Already validated to exist in profiles
        'student_usn': a['student_usn']?.toString() ?? '',
        'student_name': a['student_name']?.toString() ?? '',
        'room_id': a['room_id']?.toString() ?? '',
        'room_name': a['room_name']?.toString() ?? '',
        'seat_number': a['seat_number']?.toString() ?? '',
        'exam_date': a['exam_date']?.toString() ?? _examDate.toIso8601String(),
        'exam_time': a['exam_time']?.toString() ?? examTime,
        'subject': a['subject']?.toString() ?? examName,
        'semester': a['semester']?.toString(),
        'section': a['section']?.toString(),
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    if (allocationsToInsert.isEmpty) {
      throw Exception('No valid allocations to insert. All student IDs must exist in profiles table.');
    }

    debugPrint('Inserting ${allocationsToInsert.length} allocations into exam_allocations table...');
    
    // Insert in batches
    const batchSize = 500;
    for (var i = 0; i < allocationsToInsert.length; i += batchSize) {
      final batch = allocationsToInsert.sublist(
        i,
        i + batchSize > allocationsToInsert.length ? allocationsToInsert.length : i + batchSize,
      );
      debugPrint('Inserting batch ${(i ~/ batchSize) + 1} (${batch.length} records)...');
      await client.from('exam_allocations').insert(batch);
    }
    
    debugPrint('✓ Successfully inserted ${allocationsToInsert.length} allocations');

    // Store invigilator assignments as announcements (exam_invigilators table may not exist)
    if (result.invigilators.isNotEmpty) {
      try {
        final invigilatorAnnouncements = <Map<String, dynamic>>[];
        for (final inv in result.invigilators) {
          invigilatorAnnouncements.add({
            'title': 'Invigilation Duty Assigned',
            'body': 'You are assigned to invigilate ${inv['exam_name']} on ${inv['exam_date']?.toString().substring(0, 10)} at ${inv['exam_time']}. Room: ${inv['room_name']}',
            'audience': ['teacher'],
            'created_by': client.auth.currentUser?.id,
          });
        }
        await client.from('announcements').insert(invigilatorAnnouncements);
      } catch (e) {
        debugPrint('Error saving invigilator announcements: $e');
        // Don't throw - continue with allocation even if announcements fail
      }
    }

    // Send notifications
    if (_sendNotifications) {
      await _sendNotificationsToStudents(result);
      await _sendNotificationsToInvigilators(result);
    }

    // Show success dialog
    if (mounted) {
      final summary = result.summary;
      final totalStudents = summary['total_students'] ?? result.allocations.length;
      final totalRooms = summary['total_rooms'] ?? 'N/A';
      final totalInvigilators = summary['total_invigilators'] ?? result.invigilators.length;
      final isSingleAllocation = totalStudents == 1;
      
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Flexible(child: Text('Allocation Complete')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSingleAllocation) ...[
                  Text('✓ Student allocated successfully'),
                  const SizedBox(height: 4),
                  Text('✓ Room: $totalRooms'),
                  const SizedBox(height: 4),
                  Text('✓ Invigilator: $totalInvigilators'),
                ] else ...[
                  Text('✓ Total Students: $totalStudents'),
                  const SizedBox(height: 4),
                  Text('✓ Total Rooms: $totalRooms'),
                  const SizedBox(height: 4),
                  Text('✓ Total Invigilators: $totalInvigilators'),
                ],
                if (_sendNotifications) ...[
                  const SizedBox(height: 4),
                  const Text('✓ Notifications sent'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _sendNotificationsToStudents(AllocationResult result) async {
    final client = supabase;
    final examName = _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim();
    final dateStr = '${_examDate.year}-${_examDate.month.toString().padLeft(2, '0')}-${_examDate.day.toString().padLeft(2, '0')}';

    // Group by student for individual notifications
    final studentNotifications = <String, Map<String, dynamic>>{};
    for (final alloc in result.allocations) {
      final studentId = alloc['student_id']?.toString() ?? '';
      if (studentId.isEmpty) continue;
      
      studentNotifications[studentId] = {
        'title': 'Exam Seat Allocated',
        'body': '${examName}: Room ${alloc['room_name']}, Seat ${alloc['seat_number']} on $dateStr at ${_examTimeCtrl.text.trim()}',
        'student_id': studentId,
        'type': 'exam_allocation',
        'data': jsonEncode(alloc),
      };
    }

    // Send local notifications
    for (final notif in studentNotifications.values) {
      await NotificationService().show(
        title: notif['title'] as String,
        body: notif['body'] as String,
        payload: notif['data'] as String?,
      );
    }

    // Don't create announcements for exam allocations - students can see them in Exam Allocations section
    // This prevents duplicate notifications and keeps announcements clean
    // Exam allocations are already stored in exam_allocations table and visible in ExamNotificationsScreen
  }

  Future<void> _sendNotificationsToInvigilators(AllocationResult result) async {
    final client = supabase;
    final examName = _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim();
    final dateStr = '${_examDate.year}-${_examDate.month.toString().padLeft(2, '0')}-${_examDate.day.toString().padLeft(2, '0')}';

    // Group invigilators by faculty
    final facultyNotifications = <String, Map<String, dynamic>>{};
    for (final inv in result.invigilators) {
      final facultyId = inv['faculty_id']?.toString() ?? '';
      if (facultyId.isEmpty) continue;

      if (!facultyNotifications.containsKey(facultyId)) {
        facultyNotifications[facultyId] = {
          'title': 'Invigilation Duty Assigned',
          'body': 'You are assigned to invigilate ${examName} on $dateStr at ${_examTimeCtrl.text.trim()}. Rooms: ',
          'faculty_id': facultyId,
          'rooms': <String>[],
        };
      }
      final roomName = inv['room_name']?.toString() ?? '';
      if (roomName.isNotEmpty) {
        (facultyNotifications[facultyId]!['rooms'] as List<String>).add(roomName);
      }
    }

    // Send notifications
    for (final notif in facultyNotifications.values) {
      final rooms = (notif['rooms'] as List<String>).join(', ');
      final body = '${notif['body']}$rooms';
      
      await NotificationService().show(
        title: notif['title'] as String,
        body: body,
      );

      // Create announcement for faculty
      try {
        await client.from('announcements').insert({
          'title': notif['title'],
          'body': body,
          'audience': ['teacher'],
          'created_by': client.auth.currentUser?.id,
        });
      } catch (e) {
        debugPrint('Error saving faculty announcement: $e');
        // Don't throw - continue even if announcement fails
      }
    }
  }

  Future<void> _generateSeatMapPdf() async {
    if (_lastAllocationResult == null) return;
    
    try {
      setState(() => _loading = true);
      
      // Group allocations by room
      final roomAllocations = <String, List<Map<String, dynamic>>>{};
      for (final alloc in _lastAllocationResult!.allocations) {
        final roomId = alloc['room_id']?.toString() ?? '';
        if (roomId.isEmpty) continue;
        roomAllocations.putIfAbsent(roomId, () => []).add(alloc);
      }
      
      // Get room details
      final rooms = await supabase
          .from('rooms')
          .select()
          .inFilter('id', roomAllocations.keys.toList());
      
      final roomMap = <String, Map<String, dynamic>>{};
      for (final room in rooms) {
        roomMap[room['id'].toString()] = room;
      }
      
      // Generate PDF for each room
      final examName = _examNameCtrl.text.trim().isEmpty ? 'Exam' : _examNameCtrl.text.trim();
      final examDate = '${_examDate.year}-${_examDate.month.toString().padLeft(2, '0')}-${_examDate.day.toString().padLeft(2, '0')}';
      final examTime = _examTimeCtrl.text.trim().isEmpty ? '09:00' : _examTimeCtrl.text.trim();
      
      for (final entry in roomAllocations.entries) {
        final roomId = entry.key;
        final allocations = entry.value;
        final room = roomMap[roomId];
        
        if (room == null) continue;
        
        final roomName = room['name']?.toString() ?? 'Unknown Room';
        final layout = _roomLayouts[roomId];
        final rows = layout?['rows'] as int? ?? room['rows_count'] as int? ?? 10;
        final seatsPerRow = layout?['seats_per_row'] as int? ?? room['seats_per_row'] as int? ?? 5;
        
        // Create seat assignments map
        final seatAssignments = <String, String>{};
        final seatUSNs = <String, String>{};
        
        for (final alloc in allocations) {
          final seatNum = int.tryParse(alloc['seat_number']?.toString() ?? '0') ?? 0;
          if (seatNum <= 0) continue;
          
          // Calculate row and seat position
          final row = ((seatNum - 1) ~/ seatsPerRow) + 1;
          final seat = ((seatNum - 1) % seatsPerRow) + 1;
          final seatKey = 'R${row.toString().padLeft(2, '0')}S${seat.toString().padLeft(2, '0')}';
          
          seatAssignments[seatKey] = alloc['student_name']?.toString() ?? '';
          final usn = alloc['student_usn']?.toString();
          if (usn != null && usn.isNotEmpty) {
            seatUSNs[seatKey] = usn;
          }
        }
        
        // Generate PDF
        final pdfFile = await SeatMapPdfService.generateSeatMapPdf(
          examName: examName,
          examDate: examDate,
          examTime: examTime,
          roomName: roomName,
          rows: rows,
          seatsPerRow: seatsPerRow,
          seatAssignments: seatAssignments,
          seatUSNs: seatUSNs,
        );
        
        // Share/Download PDF
        await SeatMapPdfService.sharePdf(pdfFile, context);
      }
      
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seat map PDF generated and ready to download'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('PDF generation error: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCsv() async {
    if (_lastAllocationResult == null) return;
    
    try {
      final csvData = <List<dynamic>>[];
      csvData.add(['USN', 'Student Name', 'Room', 'Seat Number', 'Semester', 'Section', 'Exam Date', 'Exam Time']);
      
      for (final alloc in _lastAllocationResult!.allocations) {
        csvData.add([
          alloc['student_usn'] ?? '',
          alloc['student_name'] ?? '',
          alloc['room_name'] ?? '',
          alloc['seat_number'] ?? '',
          alloc['semester'] ?? '',
          alloc['section'] ?? '',
          _examDate.toString().substring(0, 10),
          _examTimeCtrl.text.trim(),
        ]);
      }

      final csv = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/exam_allocations_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported to: ${file.path}'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent accidental back navigation during operations
        if (_loading || _isProcessingCsv) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please wait for the operation to complete')),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exam Allocation'),
          actions: _showPreview && _lastAllocationResult != null
              ? [
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: _exportToCsv,
                    tooltip: 'Export to CSV',
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: _generateSeatMapPdf,
                    tooltip: 'Download Seat Map PDF',
                  ),
                ]
              : null,
        ),
      body: _loading && !_showPreview
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.network(
                      'https://assets5.lottiefiles.com/packages/lf20_jcikwtux.json',
                      repeat: true,
                      errorBuilder: (context, error, stack) => const CircularProgressIndicator(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AI is allocating seats...',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('This may take a moment'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showPreview && _lastAllocationResult != null) ...[
                    _buildPreviewTable(_lastAllocationResult!),
                    const SizedBox(height: 24),
                  ],
                  const Icon(Icons.auto_awesome, size: 64, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Auto Allocate Exams',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Intelligently assign students to rooms based on semester, section, and room capacity.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _examNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Exam Name',
                      prefixIcon: Icon(Icons.assignment),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _examTimeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Exam Time (HH:mm)',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Exam Date'),
                          subtitle: Text(
                            '${_examDate.year}-${_examDate.month.toString().padLeft(2, '0')}-${_examDate.day.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _examDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _examDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _selectRooms,
                    icon: const Icon(Icons.meeting_room),
                    label: Text(
                      _selectedRoomIds.isEmpty
                          ? 'Select Rooms'
                          : '${_selectedRoomIds.length} Room(s) Selected',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  if (_selectedRoomIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selected rooms: ${_selectedRoomIds.length}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Toggle between CSV and Section selection
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('CSV Upload'), icon: Icon(Icons.upload_file)),
                      ButtonSegment(value: true, label: Text('Select Sections'), icon: Icon(Icons.group)),
                    ],
                    selected: {_useSectionSelection},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _useSectionSelection = newSelection.first;
                        if (_useSectionSelection) {
                          _csvStudents = const [];
                          _csvSummary = null;
                        } else {
                          _selectedSections = [];
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_useSectionSelection) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Seats per bench',
                              prefixIcon: Icon(Icons.chair),
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v.trim());
                              if (n != null && n > 0) _seatsPerBench = n;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _pickCsv,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload CSV'),
                          ),
                        ),
                      ],
                    ),
                    if (_csvSummary != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _csvSummary!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _selectSections,
                      icon: const Icon(Icons.group),
                      label: Text(
                        _selectedSections.isEmpty
                            ? 'Select Sections'
                            : '${_selectedSections.length} Section(s) Selected',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                    if (_selectedSections.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSections.map((section) {
                          return Chip(
                            label: Text(section),
                            onDeleted: () {
                              setState(() {
                                _selectedSections.remove(section);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _seatsPerBenchCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Students per bench (2 or 3)',
                        prefixIcon: Icon(Icons.chair),
                        helperText: 'Seating: 3 columns × 6 benches × students per bench',
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null && n >= 2 && n <= 3) {
                          setState(() => _seatsPerBench = n);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _sendNotifications,
                    onChanged: (v) => setState(() => _sendNotifications = v ?? true),
                    title: const Text('Send notifications to students and invigilators'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  // Only show auto allocation buttons when NOT using section selection
                  if (!_useSectionSelection) ...[
                    FilledButton.icon(
                      onPressed: _loading ? null : _autoAllocate,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_loading ? 'Allocating...' : 'Start Auto Allocation'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _aiAllocate,
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text('Use AI (GPT-4o) Allocation'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loading ? null : _allocateFromCsv,
                      icon: const Icon(Icons.table_view),
                      label: const Text('Allocate from CSV'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ] else ...[
                    // Section-based allocation button
                    FilledButton.icon(
                      onPressed: _loading ? null : _allocateBySection,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.group),
                      label: Text(_loading ? 'Allocating...' : 'Allocate Selected Sections'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                    if (_selectedSections.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Only students from selected sections will be allocated: ${_selectedSections.join(", ")}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_studentsList.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Students found: ${_studentsList.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              if (_skippedStudents.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⚠ ${_skippedStudents.length} student(s) will be skipped (no profile):',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...(_skippedStudents.take(5).map((s) => Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 2),
                                  child: Text(
                                    '• $s',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ))),
                                if (_skippedStudents.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8, top: 2),
                                    child: Text(
                                      '... and ${_skippedStudents.length - 5} more',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      if (_studentsList.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          title: Text('View Students List (${_studentsList.length})'),
                          initiallyExpanded: false,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _studentsList.length,
                                itemBuilder: (context, index) {
                                  final student = _studentsList[index];
                                  final isSkipped = _skippedStudents.any((s) => s.startsWith(student['usn']?.toString() ?? ''));
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isSkipped ? Colors.orange : Colors.blue,
                                      child: Text(
                                        (student['name']?.toString() ?? '?')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    title: Text(
                                      student['name']?.toString() ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSkipped ? Colors.orange.shade900 : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'USN: ${student['usn']} | ${student['semester']}-${student['section']}',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    trailing: isSkipped
                                        ? Icon(Icons.warning, color: Colors.orange, size: 16)
                                        : Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildPreviewTable(AllocationResult result) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Allocation Preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showPreview = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result.summary.isNotEmpty) ...[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    icon: Icons.people,
                    label: 'Students',
                    value: '${result.summary['total_students'] ?? result.allocations.length}',
                  ),
                  _SummaryChip(
                    icon: Icons.meeting_room,
                    label: 'Rooms',
                    value: '${result.summary['total_rooms'] ?? 'N/A'}',
                  ),
                  _SummaryChip(
                    icon: Icons.person,
                    label: 'Invigilators',
                    value: '${result.summary['total_invigilators'] ?? result.invigilators.length}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Show allocated sections if using section selection
              if (_useSectionSelection && _selectedSections.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Allocated Sections:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSections.map((section) {
                          return Chip(
                            label: Text(section),
                            backgroundColor: Colors.green.shade100,
                            labelStyle: TextStyle(color: Colors.green.shade900),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            // Seat Maps
            if (_roomLayouts.isNotEmpty) ...[
              const Text(
                'Seat Maps',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 400,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buildSeatMaps(result),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final seatMaps = snapshot.data ?? [];
                    if (seatMaps.isEmpty) {
                      return const Center(child: Text('No seat maps available'));
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: seatMaps.length,
                      itemBuilder: (ctx, idx) {
                        final map = seatMaps[idx];
                        return SizedBox(
                          width: 400,
                          child: SeatMapWidget(
                            roomName: map['roomName'] as String,
                            rows: map['rows'] as int,
                            seatsPerRow: map['seatsPerRow'] as int,
                            seatAssignments: map['seatAssignments'] as Map<String, String>,
                            seatUSNs: map['seatUSNs'] as Map<String, String>?,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Allocation Table
            const Text(
              'Allocation Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 400,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('USN')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Room')),
                      DataColumn(label: Text('Seat')),
                      DataColumn(label: Text('Section')),
                    ],
                    rows: result.allocations.take(100).map((alloc) {
                      return DataRow(
                        cells: [
                          DataCell(Text(alloc['student_usn']?.toString() ?? '')),
                          DataCell(Text(alloc['student_name']?.toString() ?? '')),
                          DataCell(Text(alloc['room_name']?.toString() ?? '')),
                          DataCell(Text(alloc['seat_number']?.toString() ?? '')),
                          DataCell(Text(alloc['section']?.toString() ?? '')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (result.allocations.length > 100)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing first 100 of ${result.allocations.length} allocations',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buildSeatMaps(AllocationResult result) async {
    // Group allocations by room
    final roomAllocations = <String, List<Map<String, dynamic>>>{};
    for (final alloc in result.allocations) {
      final roomId = alloc['room_id']?.toString() ?? '';
      if (roomId.isEmpty) continue;
      roomAllocations.putIfAbsent(roomId, () => []).add(alloc);
    }
    
    // Get room details
    final rooms = await supabase
        .from('rooms')
        .select()
        .inFilter('id', roomAllocations.keys.toList());
    
    final roomMap = <String, Map<String, dynamic>>{};
    for (final room in rooms) {
      roomMap[room['id'].toString()] = room;
    }
    
    final seatMaps = <Map<String, dynamic>>[];
    
    for (final entry in roomAllocations.entries) {
      final roomId = entry.key;
      final allocations = entry.value;
      final room = roomMap[roomId];
      
      if (room == null) continue;
      
      final roomName = room['name']?.toString() ?? 'Unknown Room';
      final layout = _roomLayouts[roomId];
      final rows = layout?['rows'] as int? ?? room['rows_count'] as int? ?? 10;
      final seatsPerRow = layout?['seats_per_row'] as int? ?? room['seats_per_row'] as int? ?? 5;
      
      // Create seat assignments map
      final seatAssignments = <String, String>{};
      final seatUSNs = <String, String>{};
      
      for (final alloc in allocations) {
        final seatNum = int.tryParse(alloc['seat_number']?.toString() ?? '0') ?? 0;
        if (seatNum <= 0) continue;
        
        // Calculate row and seat position
        final row = ((seatNum - 1) ~/ seatsPerRow) + 1;
        final seat = ((seatNum - 1) % seatsPerRow) + 1;
        final seatKey = 'R${row.toString().padLeft(2, '0')}S${seat.toString().padLeft(2, '0')}';
        
        seatAssignments[seatKey] = alloc['student_name']?.toString() ?? '';
        final usn = alloc['student_usn']?.toString();
        if (usn != null && usn.isNotEmpty) {
          seatUSNs[seatKey] = usn;
        }
      }
      
      seatMaps.add({
        'roomName': roomName,
        'rows': rows,
        'seatsPerRow': seatsPerRow,
        'seatAssignments': seatAssignments,
        'seatUSNs': seatUSNs,
      });
    }
    
    return seatMaps;
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
      backgroundColor: Colors.blue.shade50,
    );
  }
}

class _CsvStudent {
  final String usn;
  final String name;
  final String semester;
  final String section;
  
  const _CsvStudent({
    required this.usn,
    required this.name,
    required this.semester,
    required this.section,
  });
}

class _SectionSelectionDialog extends StatefulWidget {
  final List<String> sections;
  final Set<String> selectedSections;

  const _SectionSelectionDialog({
    required this.sections,
    required this.selectedSections,
  });

  @override
  State<_SectionSelectionDialog> createState() => _SectionSelectionDialogState();
}

class _SectionSelectionDialogState extends State<_SectionSelectionDialog> {
  late Set<String> _selectedSections;

  @override
  void initState() {
    super.initState();
    _selectedSections = Set<String>.from(widget.selectedSections);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Select Sections'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.sections.length,
                itemBuilder: (ctx, idx) {
                  final section = widget.sections[idx];
                  final isSelected = _selectedSections.contains(section);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedSections.add(section);
                        } else {
                          _selectedSections.remove(section);
                        }
                      });
                    },
                    title: Text('Semester ${section.split('-')[0]}, Section ${section.split('-')[1]}'),
                    subtitle: Text('Section: $section'),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedSections.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(_selectedSections);
                          },
                    child: const Text('Confirm'),
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
