import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_config.dart';
import 'supabase_client.dart';

class AiExamAllocationService {
  final SupabaseClient _client;
  AiExamAllocationService(this._client);

  Future<AllocationResult> generateAllocations({
    required String examName,
    required DateTime examDate,
    required String examTime,
    String? subject,
    List<Map<String, dynamic>>? csvStudents,
    List<String>? selectedRoomIds,
  }) async {
    // Fetch students (from CSV if provided, else from Supabase)
    List<dynamic> students;
    if (csvStudents != null && csvStudents.isNotEmpty) {
      // Map CSV students to profiles
      final usns = csvStudents.map((s) => s['usn'] as String).where((u) => u.isNotEmpty).toList();
      if (usns.isEmpty) throw Exception('No valid USNs in CSV');
      
      final chunks = <List<String>>[];
      const chunkSize = 200;
      for (var i = 0; i < usns.length; i += chunkSize) {
        chunks.add(usns.sublist(i, i + chunkSize > usns.length ? usns.length : i + chunkSize));
      }
      
      // Try students table first, then match with profiles to get correct profiles.id
      final profileMap = <String, Map<String, dynamic>>{};
      for (final chunk in chunks) {
        try {
          // Try students table first to get semester/section info
          final studentRows = await _client.from('students').select().inFilter('usn', chunk);
          
          if (studentRows.isNotEmpty) {
            // Get USNs from students table
            final studentUsns = studentRows.map((r) => (r['usn'] ?? '').toString()).where((usn) => usn.isNotEmpty).toList();
            
            // Fetch corresponding profiles using USN to get the correct profiles.id (UUID)
            final profileRows = await _client.from('profiles')
                .select('id, usn, name, email, role')
                .inFilter('usn', studentUsns)
                .eq('role', 'student');
            
            // Create a map of USN -> profile
            final usnToProfile = <String, Map<String, dynamic>>{};
            for (final profile in profileRows) {
              final profileUsn = (profile['usn'] ?? '').toString();
              if (profileUsn.isNotEmpty) {
                usnToProfile[profileUsn] = profile;
              }
            }
            
            // Map students table data with profiles.id
            for (final r in studentRows) {
              final usn = (r['usn'] ?? '').toString();
              if (usn.isNotEmpty) {
                final profile = usnToProfile[usn];
                if (profile == null) {
                  debugPrint('Warning: No profile found for student USN: $usn. Skipping this student.');
                  continue;
                }
                
                // Use profiles.id (UUID) instead of students.id
                profileMap[usn] = {
                  'id': profile['id']?.toString() ?? '', // Use profiles.id (UUID that exists in profiles table)
                  'usn': usn,
                  'name': r['name']?.toString() ?? profile['name']?.toString() ?? '',
                  'email': r['email']?.toString() ?? profile['email']?.toString() ?? '',
                  'phone': r['phone']?.toString() ?? '',
                  'department': r['department']?.toString() ?? '',
                  'semester': r['semester']?.toString() ?? '',
                  'section': r['section']?.toString() ?? '',
                };
              }
            }
          }
        } catch (e) {
          // Fallback to profiles table if students table doesn't exist
          debugPrint('Students table not found, trying profiles: $e');
          final rows = await _client.from('profiles').select().inFilter('usn', chunk);
          for (final r in rows) {
            final usn = (r['usn'] ?? '').toString();
            if (usn.isNotEmpty) profileMap[usn] = r;
          }
        }
      }
      
      // Merge CSV data with student data
      // If using students table, prefer CSV semester/section if provided, otherwise use database values
      final matchedStudents = csvStudents.map((csv) {
        final usn = csv['usn'] as String;
        final student = profileMap[usn];
        if (student == null) return null;
        return {
          ...student,
          // Use CSV semester/section if provided, otherwise use database values
          'semester': csv['semester']?.toString() ?? student['semester']?.toString() ?? '',
          'section': csv['section']?.toString() ?? student['section']?.toString() ?? '',
        };
      }).whereType<Map<String, dynamic>>().toList();
      
      if (matchedStudents.isEmpty) {
        throw Exception('No CSV students found in database. Please ensure USNs in CSV match registered students.');
      }
      
      final unmatchedCount = csvStudents.length - matchedStudents.length;
      if (unmatchedCount > 0) {
        print('Warning: $unmatchedCount CSV students not found in database');
      }
      
      students = matchedStudents;
    } else {
      students = await _client.from('profiles').select().eq('role', 'student');
    }
    
    // Fetch available rooms (filter by selectedRoomIds if provided)
    List<dynamic> rooms;
    if (selectedRoomIds != null && selectedRoomIds.isNotEmpty) {
      rooms = await _client.from('rooms')
          .select()
          .eq('is_maintenance', false)
          .inFilter('id', selectedRoomIds);
    } else {
      rooms = await _client.from('rooms').select().eq('is_maintenance', false);
    }
    
    if (students.isEmpty || rooms.isEmpty) {
      throw Exception('No students or rooms available');
    }

    // Fetch available faculty for invigilation
    final faculty = await _client.from('profiles')
        .select('id, name, department')
        .inFilter('role', ['faculty', 'admin']);

    // If Gemini key present, use Gemini AI; else fallback to heuristic
    final apiKey = kGeminiApiKey.trim();
    if (apiKey.isNotEmpty) {
      try {
        final result = await _callGeminiPlanner(
          students: students,
          rooms: rooms,
          faculty: faculty,
          examName: examName,
          examDate: examDate,
          examTime: examTime,
          subject: subject,
        );
        if (result.allocations.isNotEmpty) {
          // Validate allocations
          final validated = await _validateAllocations(result, rooms);
          return validated;
        }
      } catch (e) {
        print('AI allocation error: $e');
        // Fallback to heuristic
      }
    }

    // Heuristic fallback
    final heuristicResult = heuristicPlan(
      students: students,
      rooms: rooms,
      faculty: faculty,
      examName: examName,
      examDate: examDate,
      examTime: examTime,
      subject: subject,
    );
    return heuristicResult;
  }

  Future<AllocationResult> _callGeminiPlanner({
    required List<dynamic> students,
    required List<dynamic> rooms,
    required List<dynamic> faculty,
    required String examName,
    required DateTime examDate,
    required String examTime,
    String? subject,
  }) async {
    
    // Prepare student data with semester/section
    final studentData = students.map((s) {
      // Extract semester from year field or semester field
      final year = s['year'];
      final semester = s['semester']?.toString() ?? 
                      (year != null ? year.toString() : '');
      return {
        'id': s['id'].toString(),
        'usn': s['usn']?.toString() ?? '',
        'name': s['name']?.toString() ?? s['email']?.toString() ?? '',
        'semester': semester,
        'section': s['section']?.toString() ?? '',
        'department': s['department']?.toString() ?? '',
      };
    }).toList();

    final roomData = rooms.map((r) {
      return {
        'id': r['id'].toString(),
        'name': r['name']?.toString() ?? '',
        'capacity': r['capacity'] as int? ?? 40,
        'building': r['building']?.toString() ?? '',
      };
    }).toList();

    final facultyData = faculty.map((f) {
      return {
        'id': f['id'].toString(),
        'name': f['name']?.toString() ?? '',
        'department': f['department']?.toString() ?? '',
      };
    }).toList();

    final systemPrompt = '''You are an intelligent exam seat allocation system. Your task is to assign students to exam rooms optimally.

CRITICAL RULES:
1. Group students by semester and section, but DO NOT place students from the same section in consecutive seats
2. Optimize room capacity utilization - aim for 85-95% fill rate, avoid empty rooms
3. Distribute students fairly across all available rooms
4. Assign invigilators to rooms (1 invigilator per 30-40 students, minimum 1 per room)
5. Ensure no room exceeds its capacity
6. Return valid JSON only with this exact structure:
{
  "allocations": [
    {
      "student_id": "uuid",
      "student_usn": "string",
      "student_name": "string",
      "room_id": "uuid",
      "room_name": "string",
      "seat_number": "integer",
      "semester": "string",
      "section": "string"
    }
  ],
  "invigilators": [
    {
      "faculty_id": "uuid",
      "faculty_name": "string",
      "room_id": "uuid",
      "room_name": "string"
    }
  ],
  "summary": {
    "total_students": integer,
    "total_rooms": integer,
    "total_invigilators": integer,
    "room_utilization": {}
  }
}''';

    final userPrompt = '''Exam Details:
- Name: $examName
- Date: ${examDate.toIso8601String()}
- Time: $examTime
- Subject: ${subject ?? examName}

Rooms:
${jsonEncode(roomData)}

Students:
${jsonEncode(studentData)}

Faculty:
${jsonEncode(facultyData)}

Requirements:
- Prevent consecutive same-section seating: true
- Optimal utilization: 85-95%
- Invigilator ratio: 1 per 30-40 students

Please allocate students to rooms and assign invigilators. Return ONLY valid JSON in the exact format specified above.''';

    final apiKey = kGeminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is empty. Please set it in lib/core/backend_config.dart');
    }

    final model = kGeminiModel.isNotEmpty ? kGeminiModel : 'gemini-1.5-flash';
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\n$userPrompt'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 4000,
        'responseMimeType': 'application/json',
      },
    };

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode >= 300) {
      // Try to parse error message
      String errorMsg = 'Gemini error ${resp.statusCode}';
      try {
        final errorData = jsonDecode(resp.body) as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        if (error != null) {
          final errorCode = error['code']?.toString() ?? '';
          final errorMessage = error['message']?.toString() ?? '';
          errorMsg = 'Gemini error ${resp.statusCode}: $errorCode - $errorMessage';
          
          if (errorCode == '403' || 
              errorMessage.toLowerCase().contains('invalid') ||
              errorMessage.toLowerCase().contains('api key') ||
              errorMessage.toLowerCase().contains('authentication') ||
              errorMessage.toLowerCase().contains('permission')) {
            errorMsg = 'Invalid API key. Please check your GEMINI_API_KEY in lib/core/backend_config.dart. Error: $errorMessage';
          } else if (errorCode == '429' || errorMessage.toLowerCase().contains('quota') || errorMessage.toLowerCase().contains('rate limit')) {
            errorMsg = 'Gemini API quota/rate limit exceeded. Check your quota at https://aistudio.google.com/app/apikey';
          }
        }
      } catch (_) {
        errorMsg = 'Gemini error ${resp.statusCode}: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}';
      }
      throw Exception(errorMsg);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List;
    if (candidates.isEmpty) {
      throw Exception('No response from Gemini API');
    }
    
    final content = (candidates.first['content'] as Map<String, dynamic>)['parts'] as List;
    if (content.isEmpty) {
      throw Exception('Empty response from Gemini API');
    }
    
    final text = (content.first['text'] as String?) ?? '';
    if (text.isEmpty) {
      throw Exception('No text in Gemini response');
    }
    
    // Try to extract JSON from the response (Gemini might wrap it in markdown)
    String jsonText = text.trim();
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.substring(7);
    }
    if (jsonText.startsWith('```')) {
      jsonText = jsonText.substring(3);
    }
    if (jsonText.endsWith('```')) {
      jsonText = jsonText.substring(0, jsonText.length - 3);
    }
    jsonText = jsonText.trim();
    
    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    
    final allocs = (parsed['allocations'] as List?) ?? [];
    final invigilators = (parsed['invigilators'] as List?) ?? [];
    final summary = parsed['summary'] as Map<String, dynamic>? ?? {};

    final allocations = allocs.map<Map<String, dynamic>>((a) {
      return {
        'exam_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'student_id': a['student_id']?.toString() ?? '',
        'student_usn': a['student_usn']?.toString() ?? '',
        'student_name': a['student_name']?.toString() ?? '',
        'room_id': a['room_id']?.toString() ?? '',
        'room_name': a['room_name']?.toString() ?? '',
        'seat_number': (a['seat_number'] is int ? a['seat_number'] : int.tryParse(a['seat_number']?.toString() ?? '1') ?? 1).toString(),
        'exam_date': examDate.toIso8601String(),
        'exam_time': examTime,
        'subject': subject ?? examName,
        'semester': a['semester']?.toString() ?? '',
        'section': a['section']?.toString() ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    final invigilatorAssignments = invigilators.map<Map<String, dynamic>>((i) {
      return {
        'faculty_id': i['faculty_id']?.toString() ?? '',
        'faculty_name': i['faculty_name']?.toString() ?? '',
        'room_id': i['room_id']?.toString() ?? '',
        'room_name': i['room_name']?.toString() ?? '',
        'exam_date': examDate.toIso8601String(),
        'exam_time': examTime,
        'exam_name': examName,
      };
    }).toList();

    return AllocationResult(
      allocations: allocations,
      invigilators: invigilatorAssignments,
      summary: summary,
    );
  }

  Future<AllocationResult> _validateAllocations(AllocationResult result, List<dynamic> rooms) async {
    // Check for duplicates
    final studentIds = <String>{};
    final duplicates = <String>[];
    for (final alloc in result.allocations) {
      final studentId = alloc['student_id']?.toString() ?? '';
      if (studentIds.contains(studentId)) {
        duplicates.add(studentId);
      }
      studentIds.add(studentId);
    }

    if (duplicates.isNotEmpty) {
      throw Exception('Duplicate student assignments found: ${duplicates.join(", ")}');
    }

    // Check room capacity
    final roomCounts = <String, int>{};
    final roomCapacities = <String, int>{};
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

    return result;
  }

  AllocationResult heuristicPlan({
    required List<dynamic> students,
    required List<dynamic> rooms,
    required List<dynamic> faculty,
    required String examName,
    required DateTime examDate,
    required String examTime,
    String? subject,
  }) {
    // Group students by semester/section
    final groups = <String, List<dynamic>>{};
    for (final s in students) {
      final sem = (s['semester']?.toString() ?? s['year']?.toString() ?? '').padLeft(2, '0');
      final sec = (s['section']?.toString() ?? '').toUpperCase();
      final key = '$sem|$sec';
      groups.putIfAbsent(key, () => []).add(s);
    }

    // Sort rooms by capacity
    final orderedRooms = [...rooms]..sort((a, b) => 
        (b['capacity'] as int? ?? 0).compareTo(a['capacity'] as int? ?? 0));

    final allocations = <Map<String, dynamic>>[];
    final roomAssignments = <String, List<dynamic>>{};
    final examId = DateTime.now().millisecondsSinceEpoch.toString();

    // Allocate students with section mixing
    // Track seat numbers per room
    final roomSeatCounts = <String, int>{};
    for (final room in orderedRooms) {
      roomSeatCounts[room['id'].toString()] = 0;
    }
    
    // Interleave students from different sections to prevent consecutive same-section seating
    final allStudents = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      for (final s in group) {
        allStudents.add({
          'student': s,
          'semester': s['semester']?.toString() ?? s['year']?.toString() ?? '',
          'section': s['section']?.toString() ?? '',
        });
      }
    }
    
    // Shuffle within each section, then interleave
    allStudents.shuffle();
    final sortedBySection = <String, List<Map<String, dynamic>>>{};
    for (final item in allStudents) {
      final key = '${item['semester']}|${item['section']}';
      sortedBySection.putIfAbsent(key, () => []).add(item);
    }
    
    // Interleave students from different sections
    final interleaved = <Map<String, dynamic>>[];
    if (sortedBySection.isNotEmpty) {
      final maxLength = sortedBySection.values.map((l) => l.length).reduce((a, b) => a > b ? a : b);
      for (var i = 0; i < maxLength; i++) {
        for (final sectionList in sortedBySection.values) {
          if (i < sectionList.length) {
            interleaved.add(sectionList[i]);
          }
        }
      }
    }

    // Track allocated students to prevent duplicates
    final allocatedStudentIds = <String>{};
    
    // Allocate students to rooms respecting capacity
    var currentRoomIndex = 0;
    for (final item in interleaved) {
      final student = item['student'] as Map<String, dynamic>;
      final studentId = student['id'].toString();
      
      // Skip if student already allocated
      if (allocatedStudentIds.contains(studentId)) {
        debugPrint('Warning: Duplicate student detected in allocation: $studentId');
        continue;
      }
      allocatedStudentIds.add(studentId);
      
      // Find a room with available capacity
      Map<String, dynamic>? selectedRoom;
      int? selectedRoomIndex;
      int seatNumber = 1;
      
      // Try to find a room with available space
      for (var attempt = 0; attempt < orderedRooms.length; attempt++) {
        final roomIndex = (currentRoomIndex + attempt) % orderedRooms.length;
        final room = orderedRooms[roomIndex];
        final roomId = room['id'].toString();
        final capacity = (room['capacity'] as int?) ?? 40;
        final currentSeats = roomSeatCounts[roomId] ?? 0;
        
        if (currentSeats < capacity) {
          selectedRoom = room;
          selectedRoomIndex = roomIndex;
          seatNumber = currentSeats + 1;
          break;
        }
      }
      
      // If no room found, throw error
      if (selectedRoom == null) {
        final totalCapacity = orderedRooms.fold<int>(0, (sum, r) => sum + ((r['capacity'] as int?) ?? 40));
        throw Exception('Not enough room capacity. Total students: ${interleaved.length}, Total capacity: $totalCapacity');
      }
      
      final roomId = selectedRoom['id'].toString();
      
      allocations.add({
        'exam_id': examId,
        'student_id': student['id'].toString(),
        'student_usn': student['usn']?.toString() ?? '',
        'student_name': student['name']?.toString() ?? student['email']?.toString() ?? '',
        'room_id': roomId,
        'room_name': selectedRoom['name']?.toString() ?? '',
        'seat_number': seatNumber.toString(),
        'exam_date': examDate.toIso8601String(),
        'exam_time': examTime,
        'subject': subject ?? examName,
        'semester': item['semester']?.toString() ?? '',
        'section': item['section']?.toString() ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });

      roomAssignments.putIfAbsent(roomId, () => []).add(allocations.last);
      roomSeatCounts[roomId] = seatNumber;
      
      // Move to next room for next student (round-robin)
      currentRoomIndex = (selectedRoomIndex! + 1) % orderedRooms.length;
    }

    // Assign invigilators (1 per 35 students, minimum 1 per room)
    final invigilators = <Map<String, dynamic>>[];
    final assignedFaculty = <String>{};
    var facultyIndex = 0;

    for (final roomId in roomAssignments.keys) {
      final studentsInRoom = roomAssignments[roomId]!.length;
      final invigilatorsNeeded = (studentsInRoom / 35).ceil().clamp(1, 3);
      final room = orderedRooms.firstWhere((r) => r['id'].toString() == roomId);
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
      final room = orderedRooms.firstWhere((r) => r['id'].toString() == roomId);
      final capacity = room['capacity'] as int? ?? 40;
      final used = students.length;
      roomUtilization[roomId] = {
        'room_name': room['name']?.toString() ?? '',
        'capacity': capacity,
        'used': used,
        'utilization': ((used / capacity) * 100).toStringAsFixed(1),
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
}

class AllocationResult {
  final List<Map<String, dynamic>> allocations;
  final List<Map<String, dynamic>> invigilators;
  final Map<String, dynamic> summary;

  AllocationResult({
    required this.allocations,
    required this.invigilators,
    required this.summary,
  });
}

final aiExamAllocationService = AiExamAllocationService(supabase);

