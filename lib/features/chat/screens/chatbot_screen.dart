import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import '../../../core/backend_config.dart';
import '../../../core/supabase_client.dart';
import '../../timetable/models/timetable_model.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _hasText = _textController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading || _isSending) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isLoading = true;
      _isSending = true;
      _textController.clear();
      _hasText = false;
    });
    _scrollToBottom();

    try {
      final apiKey = kGeminiApiKey.trim();
      bool useFallback = apiKey.isEmpty;
      
      if (!useFallback) {
        // Try multiple models in order of availability
        // Start with configured model, then try common alternatives
        final modelsToTry = <String>[];
        if (kGeminiModel.isNotEmpty) {
          modelsToTry.add(kGeminiModel);
        }
        
        // Add fallback models (try these if configured model fails)
        // gemini-pro is the most widely available model
        if (!modelsToTry.contains('gemini-pro')) {
          modelsToTry.add('gemini-pro');
        }
        // Try newer models if available
        if (!modelsToTry.contains('gemini-1.5-flash')) {
          modelsToTry.add('gemini-1.5-flash');
        }

        http.Response? response;
        String? modelUsed;
        String? lastError;

        for (final modelToUse in modelsToTry) {
          try {
            debugPrint('Trying Gemini model: $modelToUse');
            modelUsed = modelToUse;

            // Convert messages to Gemini format (contents → parts → text)
            final contents = _messages
                .where((m) => m.role != 'assistant' || m.content.isNotEmpty)
                .map((m) {
              return {
                'role': m.role == 'user' ? 'user' : 'model',
                'parts': [
                  {'text': m.content}
                ],
              };
            }).toList();

            final requestBody = {
              'contents': contents,
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 2048,
                'topP': 0.95,
                'topK': 40,
              },
            };

            final uri = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$modelToUse:generateContent?key=$apiKey',
            );

            response = await http.post(
              uri,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(requestBody),
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout');
              },
            );

            debugPrint('Gemini response status: ${response.statusCode}');

            if (response.statusCode >= 200 && response.statusCode < 300) {
              // Success! Break out of loop
              break;
            } else {
              // Try to parse error
              try {
                final errorData = jsonDecode(response.body) as Map<String, dynamic>;
                final error = errorData['error'] as Map<String, dynamic>?;
                if (error != null) {
                  final errorCode = error['code']?.toString() ?? '';
                  final errorMessage = error['message']?.toString() ?? 'Unknown error';
                  lastError = '$errorCode: $errorMessage';
                  debugPrint('Model $modelToUse failed: $lastError');

                  // If it's a model-specific error, try next model
                  if (errorCode == '404' ||
                      errorMessage.toLowerCase().contains('model') ||
                      errorMessage.toLowerCase().contains('not found')) {
                    continue; // Try next model
                  }
                  // If it's quota or invalid key, don't try other models
                  if (errorCode == '429' ||
                      errorCode == '403' ||
                      errorMessage.toLowerCase().contains('quota') ||
                      errorMessage.toLowerCase().contains('api key') ||
                      errorMessage.toLowerCase().contains('permission')) {
                    break; // Stop trying
                  }
                }
              } catch (_) {}
              // Continue to next model
              continue;
            }
          } catch (e) {
            debugPrint('Error trying model $modelToUse: $e');
            lastError = e.toString();
            if (e.toString().contains('timeout')) {
              break; // Don't try other models on timeout
            }
            continue; // Try next model
          }
        }

        if (response == null || response.statusCode >= 300) {
          // Fallback to simple rule-based chatbot
          useFallback = true;
        } else if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final candidates = data['candidates'] as List?;

            if (candidates == null || candidates.isEmpty) {
              // Check for safety ratings
              final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
              if (promptFeedback != null) {
                final blockReason = promptFeedback['blockReason']?.toString() ?? '';
                if (blockReason.isNotEmpty) {
                  setState(() {
                    _messages.add(ChatMessage(
                      role: 'assistant',
                      content: '⚠️ **Response blocked**\n\n'
                          'The response was blocked due to safety filters. Please try rephrasing your question.',
                    ));
                    _isLoading = false;
                    _isSending = false;
                  });
                  _scrollToBottom();
                  return;
                }
              }

              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: "I'm not sure how to respond. Please try again.",
                ));
                _isLoading = false;
                _isSending = false;
              });
              _scrollToBottom();
              return;
            }

            final candidate = candidates.first as Map<String, dynamic>;
            final content = candidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;

            if (parts == null || parts.isEmpty) {
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: "I'm not sure how to respond. Please try rephrasing your question.",
                ));
                _isLoading = false;
                _isSending = false;
              });
              _scrollToBottom();
              return;
            }

            final textPart = parts.first as Map<String, dynamic>;
            final text = textPart['text'] as String? ?? '';

            if (text.isEmpty) {
              setState(() {
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: "I'm not sure how to respond. Please try again.",
                ));
                _isLoading = false;
                _isSending = false;
              });
              _scrollToBottom();
              return;
            }

            // Successfully got response
            setState(() {
              _messages.add(ChatMessage(role: 'assistant', content: text));
              _isLoading = false;
              _isSending = false;
            });
            _scrollToBottom();

            if (modelUsed != kGeminiModel && modelUsed != 'gemini-1.5-flash') {
              debugPrint('Note: Used fallback model $modelUsed');
            }
          } catch (e, stackTrace) {
            debugPrint('Error parsing Gemini response: $e');
            debugPrint('Stack trace: $stackTrace');
            useFallback = true;
          }
        }
      }
      
      // Use fallback chatbot if API failed or key is empty
      if (useFallback) {
        debugPrint('Using fallback chatbot');
        final fallbackResponse = await _getFallbackResponse(text);
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: fallbackResponse));
          _isLoading = false;
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('Chatbot error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Use fallback on any error
      final fallbackResponse = await _getFallbackResponse(text);
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: fallbackResponse));
        _isLoading = false;
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI'),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start a conversation',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask about rooms, classes, or anything else!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          // Typing indicator
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index], primaryColor);
                      },
                    ),
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isLoading && !_isSending,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendButton(primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, Color primaryColor) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? SelectableText(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        h1: TextStyle(
                          color: Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        strong: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        em: const TextStyle(
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          backgroundColor: Colors.grey[200],
                          color: Colors.black87,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        listBullet: const TextStyle(
                          color: Colors.black87,
                        ),
                        blockquote: TextStyle(
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border(
                            left: BorderSide(
                              color: Colors.grey[400]!,
                              width: 4,
                            ),
                          ),
                        ),
                        a: TextStyle(
                          color: Colors.blue[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 18,
                color: primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[100],
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI is thinking',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getFallbackResponse(String userMessage) async {
    final message = userMessage.toLowerCase();
    final user = supabase.auth.currentUser;
    
    if (user == null) {
      return 'Please log in to get personalized information.';
    }
    
    try {
      // Next class / Current class
      if (message.contains('next class') || 
          message.contains('current class') || 
          message.contains('where is my class') ||
          message.contains('what is my next class')) {
        return await _getNextClassInfo(user.id);
      }
      
      // Today's schedule
      if (message.contains('today') && (message.contains('class') || message.contains('schedule'))) {
        return await _getTodaysSchedule(user.id);
      }
      
      // Free rooms
      if (message.contains('free room') || 
          message.contains('available room') ||
          message.contains('which room') && message.contains('free')) {
        return await _getFreeRooms();
      }
      
      // Room information
      if (message.contains('room') && !message.contains('free')) {
        return await _getRoomsInfo();
      }
      
      // Announcements
      if (message.contains('announcement') || 
          message.contains('news') || 
          message.contains('notice') ||
          message.contains('update')) {
        return await _getAnnouncements();
      }
      
      // Profile
      if (message.contains('profile') || 
          message.contains('my info') || 
          message.contains('my details') ||
          message.contains('who am i')) {
        return await _getProfileInfo(user.id);
      }
      
      // Greetings
      if (message.contains('hello') || message.contains('hi') || message.contains('hey')) {
        return 'Hello! 👋 I\'m here to help you with information about VVCE. How can I assist you today?';
      }
      
      // Help
      if (message.contains('help') || message.contains('what can you do')) {
        return '**I can help you with:**\n\n'
            '• **Next Class** - "What is my next class?" or "Where is my next class?"\n'
            '• **Today\'s Schedule** - "Show my classes today"\n'
            '• **Free Rooms** - "Which rooms are free now?"\n'
            '• **Announcements** - "Show me announcements"\n'
            '• **Profile** - "Show my profile"\n\n'
            'Just ask me about any of these topics!';
      }
      
      // Default response
      return 'I understand you\'re asking about "$userMessage".\n\n'
          'I can help you with:\n'
          '• Next class information\n'
          '• Today\'s schedule\n'
          '• Free rooms\n'
          '• Announcements\n'
          '• Your profile\n\n'
          'Try asking: "What is my next class?" or "Which rooms are free now?"';
    } catch (e) {
      debugPrint('Error fetching data: $e');
      return 'I encountered an error while fetching information. Please try again or check your connection.';
    }
  }
  
  Future<String> _getNextClassInfo(String userId) async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Get today's timetable entries
      final entries = await supabase
          .from('timetables')
          .select()
          .eq('user_id', userId)
          .eq('day_of_week', weekday);
      
      // Sort by start_time
      entries.sort((a, b) {
        final aTime = (a['start_time'] as String? ?? '').compareTo(b['start_time'] as String? ?? '');
        return aTime;
      });
      
      if (entries.isEmpty) {
        return '**No classes scheduled for today.**\n\nYou have a free day! 🎉';
      }
      
      // Find current or next class
      TimetableEntry? currentClass;
      TimetableEntry? nextClass;
      
      for (final e in entries) {
        final start = (e['start_time'] as String?) ?? '';
        final end = (e['end_time'] as String?) ?? '';
        
        // Check if currently in this class
        if (_isTimeInRange(currentTime, start, end)) {
          currentClass = TimetableEntry(
            id: e['id'].toString(),
            studentId: userId,
            facultyId: e['faculty_id'] as String?,
            roomId: (e['room_id'] ?? '') as String,
            roomName: (e['room'] ?? '') as String,
            subject: (e['subject'] ?? '') as String,
            dayOfWeek: weekday.toString(),
            startTime: start,
            endTime: end,
            semester: e['semester'] as String?,
            section: e['section'] as String?,
            department: e['department'] as String?,
          );
        }
        
        // Find next class
        if (nextClass == null && _isTimeAfter(currentTime, start)) {
          nextClass = TimetableEntry(
            id: e['id'].toString(),
            studentId: userId,
            facultyId: e['faculty_id'] as String?,
            roomId: (e['room_id'] ?? '') as String,
            roomName: (e['room'] ?? '') as String,
            subject: (e['subject'] ?? '') as String,
            dayOfWeek: weekday.toString(),
            startTime: start,
            endTime: end,
            semester: e['semester'] as String?,
            section: e['section'] as String?,
            department: e['department'] as String?,
          );
        }
      }
      
      if (currentClass != null) {
        String facultyName = '';
        if (currentClass.facultyId != null && currentClass.facultyId!.isNotEmpty) {
          final faculty = await supabase
              .from('profiles')
              .select('name')
              .eq('id', currentClass.facultyId!)
              .maybeSingle();
          facultyName = faculty?['name'] as String? ?? '';
        }
        
        return '**Current Class:**\n\n'
            '📚 **${currentClass.subject}**\n'
            '🕐 Time: ${currentClass.startTime} - ${currentClass.endTime}\n'
            '🚪 Room: ${currentClass.roomName.isNotEmpty ? currentClass.roomName : "Not assigned"}\n'
            '${facultyName.isNotEmpty ? "👨‍🏫 Faculty: $facultyName\n" : ""}'
            '\nYou are currently in this class!';
      }
      
      if (nextClass != null) {
        String facultyName = '';
        if (nextClass.facultyId != null && nextClass.facultyId!.isNotEmpty) {
          final faculty = await supabase
              .from('profiles')
              .select('name')
              .eq('id', nextClass.facultyId!)
              .maybeSingle();
          facultyName = faculty?['name'] as String? ?? '';
        }
        
        return '**Next Class:**\n\n'
            '📚 **${nextClass.subject}**\n'
            '🕐 Time: ${nextClass.startTime} - ${nextClass.endTime}\n'
            '🚪 Room: ${nextClass.roomName.isNotEmpty ? nextClass.roomName : "Not assigned"}\n'
            '${facultyName.isNotEmpty ? "👨‍🏫 Faculty: $facultyName\n" : ""}';
      }
      
      return '**No more classes today.**\n\nYou\'re done for the day! 🎉';
    } catch (e) {
      debugPrint('Error getting next class: $e');
      return 'Unable to fetch your next class information. Please try again.';
    }
  }
  
  Future<String> _getTodaysSchedule(String userId) async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday;
      
      final entries = await supabase
          .from('timetables')
          .select()
          .eq('user_id', userId)
          .eq('day_of_week', weekday);
      
      // Sort by start_time
      entries.sort((a, b) {
        final aTime = (a['start_time'] as String? ?? '').compareTo(b['start_time'] as String? ?? '');
        return aTime;
      });
      
      if (entries.isEmpty) {
        return '**No classes scheduled for today.**\n\nYou have a free day! 🎉';
      }
      
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final dayName = days[weekday - 1];
      
      String schedule = '**Today\'s Schedule ($dayName):**\n\n';
      
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final subject = e['subject'] as String? ?? '';
        final start = e['start_time'] as String? ?? '';
        final end = e['end_time'] as String? ?? '';
        final room = e['room'] as String? ?? '';
        
        schedule += '${i + 1}. **$subject**\n';
        schedule += '   🕐 $start - $end\n';
        if (room.isNotEmpty) {
          schedule += '   🚪 Room: $room\n';
        }
        schedule += '\n';
      }
      
      return schedule;
    } catch (e) {
      debugPrint('Error getting today\'s schedule: $e');
      return 'Unable to fetch your schedule. Please try again.';
    }
  }
  
  Future<String> _getFreeRooms() async {
    try {
      final now = DateTime.now();
      final currentTime = now.toIso8601String();
      
      // Get all rooms
      final rooms = await supabase
          .from('rooms')
          .select()
          .eq('is_maintenance', false);
      
      // Get current reservations
      final reservations = await supabase
          .from('room_reservations')
          .select('room_id, start_time, end_time, status')
          .eq('status', 'approved')
          .lte('start_time', currentTime)
          .gte('end_time', currentTime);
      
      final reservedRoomIds = reservations.map((r) => r['room_id'] as String).toSet();
      
      // Get rooms currently in use from timetable
      final weekday = now.weekday;
      final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final timetableEntries = await supabase
          .from('timetables')
          .select('room_id, start_time, end_time')
          .eq('day_of_week', weekday)
          .not('room_id', 'is', null);
      
      final occupiedRoomIds = <String>{};
      for (final entry in timetableEntries) {
        final roomId = entry['room_id'] as String?;
        final start = entry['start_time'] as String? ?? '';
        final end = entry['end_time'] as String? ?? '';
        
        if (roomId != null && roomId.isNotEmpty && _isTimeInRange(currentTimeStr, start, end)) {
          occupiedRoomIds.add(roomId);
        }
      }
      
      // Find free rooms
      final freeRooms = rooms.where((r) {
        final roomId = r['id'] as String;
        return !reservedRoomIds.contains(roomId) && !occupiedRoomIds.contains(roomId);
      }).toList();
      
      if (freeRooms.isEmpty) {
        return '**No free rooms available right now.**\n\nAll rooms are currently occupied or reserved.';
      }
      
      String response = '**Free Rooms Now:**\n\n';
      for (var i = 0; i < freeRooms.length && i < 10; i++) {
        final room = freeRooms[i];
        final name = room['name'] as String? ?? '';
        final building = room['building'] as String? ?? '';
        final capacity = room['capacity'] as int? ?? 0;
        
        response += '${i + 1}. **$name**\n';
        if (building != null && building.isNotEmpty) {
          response += '   🏢 Building: $building\n';
        }
        response += '   👥 Capacity: $capacity\n\n';
      }
      
      if (freeRooms.length > 10) {
        response += '... and ${freeRooms.length - 10} more rooms available.';
      }
      
      return response;
    } catch (e) {
      debugPrint('Error getting free rooms: $e');
      return 'Unable to fetch free rooms. Please try again.';
    }
  }
  
  Future<String> _getRoomsInfo() async {
    try {
      final rooms = await supabase
          .from('rooms')
          .select()
          .eq('is_maintenance', false)
          .limit(10);
      
      if (rooms.isEmpty) {
        return 'No rooms available in the system.';
      }
      
      String response = '**Available Rooms:**\n\n';
      for (var i = 0; i < rooms.length; i++) {
        final room = rooms[i];
        final name = room['name'] as String? ?? '';
        final building = room['building'] as String? ?? '';
        final capacity = room['capacity'] as int? ?? 0;
        
        response += '${i + 1}. **$name**\n';
        if (building != null && building.isNotEmpty) {
          response += '   🏢 Building: $building\n';
        }
        response += '   👥 Capacity: $capacity\n\n';
      }
      
      return response;
    } catch (e) {
      debugPrint('Error getting rooms: $e');
      return 'Unable to fetch room information. Please try again.';
    }
  }
  
  Future<String> _getAnnouncements() async {
    try {
      final announcements = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(5);
      
      if (announcements.isEmpty) {
        return '**No announcements available.**\n\nCheck back later for updates!';
      }
      
      String response = '**Latest Announcements:**\n\n';
      for (var i = 0; i < announcements.length; i++) {
        final ann = announcements[i];
        final title = ann['title'] as String? ?? '';
        final content = ann['content'] as String? ?? '';
        final createdAt = ann['created_at'] as String? ?? '';
        
        response += '${i + 1}. **$title**\n';
        if (content != null && content.isNotEmpty) {
          final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;
          response += '   $preview\n';
        }
        if (createdAt != null && createdAt.isNotEmpty) {
          try {
            final date = DateTime.parse(createdAt);
            response += '   📅 ${date.day}/${date.month}/${date.year}\n';
          } catch (_) {}
        }
        response += '\n';
      }
      
      return response;
    } catch (e) {
      debugPrint('Error getting announcements: $e');
      return 'Unable to fetch announcements. Please try again.';
    }
  }
  
  Future<String> _getProfileInfo(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (profile == null) {
        return 'Profile information not found.';
      }
      
      final name = profile['name'] as String? ?? '';
      final email = profile['email'] as String? ?? '';
      final usn = profile['usn'] as String? ?? '';
      final department = profile['department'] as String? ?? '';
      final year = profile['year'] as int?;
      final role = profile['role'] as String? ?? '';
      
      String response = '**Your Profile:**\n\n';
      if (name.isNotEmpty) response += '👤 **Name:** $name\n';
      if (email.isNotEmpty) response += '📧 **Email:** $email\n';
      if (usn.isNotEmpty) response += '🆔 **USN:** $usn\n';
      if (department != null && department.isNotEmpty) response += '🏫 **Department:** $department\n';
      if (year != null) response += '📚 **Year:** $year\n';
      if (role.isNotEmpty) response += '👥 **Role:** ${role.toUpperCase()}\n';
      
      return response;
    } catch (e) {
      debugPrint('Error getting profile: $e');
      return 'Unable to fetch your profile. Please try again.';
    }
  }
  
  bool _isTimeInRange(String current, String start, String end) {
    try {
      final currentMin = _timeToMinutes(current);
      final startMin = _timeToMinutes(start);
      final endMin = _timeToMinutes(end);
      return currentMin >= startMin && currentMin <= endMin;
    } catch (_) {
      return false;
    }
  }
  
  bool _isTimeAfter(String current, String target) {
    try {
      final currentMin = _timeToMinutes(current);
      final targetMin = _timeToMinutes(target);
      return currentMin < targetMin;
    } catch (_) {
      return false;
    }
  }
  
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  Widget _buildSendButton(Color primaryColor) {
    final isEnabled = !_isLoading && !_isSending && _hasText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: isEnabled ? primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isEnabled ? _sendMessage : null,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: _isLoading || _isSending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: isEnabled ? Colors.white : Colors.grey[500],
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});
}
