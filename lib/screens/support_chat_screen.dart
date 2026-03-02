import 'dart:async';
import 'package:flutter/material.dart';
import '../services/support_service.dart';
import '../services/user_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/modern_chat_input.dart';
import '../widgets/message_bubble.dart';
import '../models/message_model.dart';
import 'support_tickets_screen.dart';

extension DateTimeSupport on DateTime {
  int get ms => millisecondsSinceEpoch;
}

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _userId;

  List<Map<String, dynamic>> _dbMessages = [];
  List<Message> _transientMessages = [];
  bool _isLoading = true;
  bool _isManualInput = false;
  bool _isBotTyping = false;

  // Bot Flow State
  // Modes: 'idle' (Bot Menu), 'agent_pending' (Waiting for Agent), 'agent_esc' (Live Support), 'collecting_*' (Bot Flows)
  String _botFlowState = 'idle';
  final Map<String, dynamic> _ticketDraft = {};
  int _botAttemptCount = 0;
  StreamSubscription? _supportSubscription;
  Timer? _inactivityTimer;
  String? _liveChatRequestId; // Track the live chat request

  @override
  void initState() {
    super.initState();
    _initSupport();
  }

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_botFlowState == 'agent_esc') {
      _inactivityTimer = Timer(const Duration(minutes: 5), () {
        if (mounted && _botFlowState == 'agent_esc') {
          // Check if last message was from user (not admin/bot)
          final lastUserMessageTime = _getLastUserMessageTime();
          if (lastUserMessageTime != null) {
            final inactivityDuration = DateTime.now().difference(lastUserMessageTime);
            if (inactivityDuration.inMinutes >= 5) {
              // Clear the chat and reset to idle
              setState(() {
                _botFlowState = 'idle';
                _isManualInput = false;
                _dbMessages.clear();
                _transientMessages.clear();
                _addBotTransient(
                    'Live session closed due to inactivity. ⏳\nI\'m back to help! How can I assist you today?');
              });
              _scrollToBottom();
              
              // Clear messages from database
              if (_userId != null) {
                SupportService.instance.clearMessages(_userId!);
              }
            }
          }
        }
      });
    }
  }

  Future<void> _requestLiveChat() async {
    if (_userId == null) return;

    debugPrint('🔵 [LIVE_CHAT] Step 1: Creating request for user: $_userId');

    setState(() {
      _botFlowState = 'agent_pending';
      _isManualInput = false;
    });

    // Create live chat request in database
    try {
      final requestId = await SupportService.instance.createLiveChatRequest(
        userId: _userId!,
      );
      
      debugPrint('🔵 [LIVE_CHAT] Step 2: Request created with ID: $requestId');
      
      setState(() {
        _liveChatRequestId = requestId;
      });

      // Send notification message to admin
      await SupportService.instance.sendSupportMessage(
        userId: _userId!,
        text: "👋 User is requesting live chat support.",
        isFromAdmin: false,
        metadata: {
          'type': 'live_chat_request',
          'request_id': requestId,
          'from_system': true,
        },
      );

      debugPrint('🔵 [LIVE_CHAT] Step 3: Notification sent to admin');

      // Listen for request status changes
      _listenToLiveChatRequestStatus();
    } catch (e) {
      debugPrint('❌ [LIVE_CHAT] Error requesting live chat: $e');
      setState(() {
        _botFlowState = 'idle';
      });
      _addBotTransient(
        'Sorry, unable to connect to live chat at the moment. Please try again later.',
      );
    }
  }

  void _listenToLiveChatRequestStatus() {
    if (_liveChatRequestId == null) return;

    debugPrint('🔵 [LIVE_CHAT] Step 4: Listening to request: $_liveChatRequestId');

    // Listen to the live_chat_requests table for status changes
    SupportService.instance
        .listenToLiveChatRequest(_liveChatRequestId!)
        .listen((request) {
      if (!mounted) return;

      final status = request['status'] as String?;
      debugPrint('🔵 [LIVE_CHAT] Step 5: Status update received: $status');
      
      if (status == 'accepted') {
        debugPrint('✅ [LIVE_CHAT] Request accepted! Entering live chat mode');
        setState(() {
          _botFlowState = 'agent_esc';
          _isManualInput = true;
          _transientMessages.clear();
        });
        _addBotTransient(
          '🤝 You\'re now connected to our support team!\n\nA human teammate is here to help. Feel free to describe your issue in detail.',
        );
        _resetInactivityTimer();
      } else if (status == 'rejected') {
        debugPrint('❌ [LIVE_CHAT] Request rejected');
        setState(() {
          _botFlowState = 'idle';
          _isManualInput = false;
          _liveChatRequestId = null;
        });
        _addBotTransient(
          'Sorry, our support team is currently unavailable. You can:\n\n• Try again later\n• Submit a support ticket\n• Continue chatting with me',
          [
            {'label': 'Try Again 🔄', 'action': 'talk_to_agent'},
            {'label': 'Open Ticket 🎫', 'action': 'start_ticket'},
            {'label': 'Back to Menu 🏠', 'action': 'back_to_menu'},
          ],
        );
      }
    });
  }

  DateTime? _getLastUserMessageTime() {
    // Check both DB messages and transient messages for last user message
    DateTime? lastUserTime;
    
    // Check DB messages (from_admin: false means from user)
    for (var msg in _dbMessages.reversed) {
      if (msg['from_admin'] == false) {
        final timestamp = msg['timestamp'];
        if (timestamp != null) {
          lastUserTime = DateTime.parse(timestamp);
          break;
        }
      }
    }
    
    // Check transient messages (senderId == _userId means from user)
    for (var msg in _transientMessages.reversed) {
      if (msg.senderId == _userId) {
        if (lastUserTime == null || msg.timestamp.isAfter(lastUserTime)) {
          lastUserTime = msg.timestamp;
        }
        break;
      }
    }
    
    return lastUserTime;
  }

  Future<void> _initSupport() async {
    final user = await UserService.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _userId = user.id;
        });
      }
      _loadMessages();
      SupportService.instance.listenToSupportMessages(user.id);
      _supportSubscription = SupportService.instance
          .getSupportMessagesStream(user.id)
          .listen((msgs) {
        if (mounted) {
          final int oldLen = _dbMessages.length;
          setState(() {
            _dbMessages = List.from(msgs);
            _isLoading = false;
          });
          _scrollToBottom();

          // Reset inactivity timer only if a new message from USER is received
          if (msgs.length > oldLen) {
            final lastMsg = msgs.isNotEmpty ? msgs.last : null;
            if (lastMsg != null && lastMsg['from_admin'] == false) {
              _resetInactivityTimer();
            }
          }
        }
      });
    }
  }

  Future<void> _loadMessages() async {
    if (_userId == null) return;
    final msgs = await SupportService.instance.fetchSupportMessages(_userId!);

    // Auto-clean old sessions (Older than 1 hour)
    if (msgs.isNotEmpty) {
      final lastMsg = msgs.last;
      if (lastMsg['timestamp'] != null) {
        final lastTime = DateTime.parse(lastMsg['timestamp']);
        if (DateTime.now().difference(lastTime).inHours >= 1) {
          await SupportService.instance.clearMessages(_userId!);
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _dbMessages = List.from(msgs);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _resetChatSession() async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Reset Chat?'),
              content: const Text(
                  'This will permanently delete your chat history with Boofer.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete All',
                        style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm != true) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      await SupportService.instance.clearMessages(_userId!);
      setState(() {
        _dbMessages = [];
        _transientMessages = [];
        _botFlowState = 'idle';
        _botAttemptCount = 0;
        _isManualInput = false;
        _ticketDraft.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage([String? text]) async {
    final finalByText = text ?? _messageController.text.trim();
    if (finalByText.isEmpty || _userId == null) return;

    _messageController.clear();

    // REAL-TIME SYNC LOGIC:
    // If we are in 'idle' (general chat) or 'agent_esc' (talking to human),
    // we send directly to Supabase. This alerts the Admin Dashboard.
    if (_botFlowState == 'idle' || _botFlowState == 'agent_esc') {
      await SupportService.instance.sendSupportMessage(
        userId: _userId!,
        text: finalByText,
        isFromAdmin: false,
      );
      _resetInactivityTimer();
    } else {
      // Inside a bot flow (Bug/Ticket), keep it transient/local UI only
      setState(() {
        _transientMessages.add(Message(
          id: DateTime.now().ms.toString(),
          senderId: _userId!,
          receiverId: 'admin',
          text: finalByText,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          isEncrypted: false,
        ));
      });
      _scrollToBottom();
    }

    _processUserMessage(finalByText);
  }

  void _processUserMessage(String text) {
    if (_botFlowState == 'idle') {
      _botAttemptCount++;
      if (_botAttemptCount >= 3) {
        _addBotTransient(
            'It seems I haven\'t been able to solve your query yet. Would you like to speak with a human teammate? 🤝',
            [
              {'label': 'Yes, Chat with Team 🤝', 'action': 'talk_to_agent'},
              {'label': 'No, I\'ll keep trying 🤖', 'action': 'back_to_menu'},
            ]);
      } else {
        _simulateBotResponse();
      }
    } else if (_botFlowState == 'agent_esc') {
      // Human teammate is handling this mode. Bot stays out of the way.
      // Optionally show a "Human is typing..." indicator if we had that state from DB.
    } else if (_botFlowState == 'review_ticket' ||
        _botFlowState == 'review_bug') {
      // Ignore typing during review buttons mode
    } else if (_botFlowState == 'collecting_ticket_title') {
      _ticketDraft['title'] = text;
      _botFlowState = 'collecting_ticket_desc';
      _addBotTransient(
          'Excellent. Now, describe your request in detail for our team. 📝');
    } else if (_botFlowState == 'collecting_ticket_desc') {
      _ticketDraft['description'] = text;
      _botFlowState = 'review_ticket';
      _addBotTransient(
          'All set! Here is a summary of your ticket:\n\n► Category: ${_ticketDraft['category']}\n► Location: ${_ticketDraft['location']}\n► Title: ${_ticketDraft['title']}\n\nReady to submit?',
          [
            {'label': 'Submit Ticket 🎫', 'action': 'confirm_ticket'},
            {'label': 'Discard 🗑️', 'action': 'back_to_menu'},
          ]);
    } else if (_botFlowState == 'collecting_bug_title') {
      _ticketDraft['title'] = text;
      _botFlowState = 'collecting_bug_steps';
      _addBotTransient('What steps can I follow to see this bug myself? 🪜');
    } else if (_botFlowState == 'collecting_bug_steps') {
      _ticketDraft['steps'] = text;
      _botFlowState = 'collecting_bug_expected';
      _addBotTransient('What did you expect to happen? 💭');
    } else if (_botFlowState == 'collecting_bug_expected') {
      _ticketDraft['expected'] = text;
      _botFlowState = 'collecting_bug_actual';
      _addBotTransient('And what actually happened? ❗');
    } else if (_botFlowState == 'collecting_bug_actual') {
      _ticketDraft['actual'] = text;
      _botFlowState = 'review_bug';
      _addBotTransient(
          'Perfect. Review your bug report:\n\n► Area: ${_ticketDraft['area']}\n► Title: ${_ticketDraft['title']}\n► Severity: ${_ticketDraft['severity'].toString().toUpperCase()}\n\nSend to developers?',
          [
            {'label': 'Submit Report 🐛', 'action': 'confirm_bug'},
            {'label': 'Discard 🗑️', 'action': 'back_to_menu'},
          ]);
    } else if (_botFlowState == 'collecting_feedback_msg') {
      _ticketDraft['message'] = text;
      _submitBundledFeedback();
    }
  }

  // --- BOT BUNDLED SUBMISSIONS ---

  Future<void> _submitBundledTicket() async {
    setState(() => _isBotTyping = true);
    try {
      final String shortId = SupportService.generateShortId();
      await SupportService.instance.createTicket(
        userId: _userId!,
        title: _ticketDraft['title'],
        description: _ticketDraft['description'],
        ticketNumber: '#$shortId',
      );

      String summary = "🎫 *Ticket Detail Received (#$shortId)*\n"
          "► Category: ${_ticketDraft['category']}\n"
          "► Location: ${_ticketDraft['location']}\n"
          "► Title: ${_ticketDraft['title']}\n"
          "► Status: Open 🟢";

      _finalizeFlow(summary);
    } catch (e) {
      _finalizeFlow('Failed to create ticket.');
    }
  }

  Future<void> _submitBundledBug() async {
    setState(() => _isBotTyping = true);
    try {
      await SupportService.instance.reportBug(
        userId: _userId!,
        title: _ticketDraft['title'],
        description: 'Guided Bug Report',
        steps: _ticketDraft['steps'],
        expected: _ticketDraft['expected'],
        actual: _ticketDraft['actual'],
        severity: _ticketDraft['severity'],
      );

      String summary = "🐛 *Bug Report Bundled*\n"
          "► Title: ${_ticketDraft['title']}\n"
          "► Area: ${_ticketDraft['area']}\n"
          "► Severity: ${_ticketDraft['severity'].toString().toUpperCase()}\n"
          "► Status: Sent to Dev Group ⚡";

      _finalizeFlow(summary);
    } catch (e) {
      _finalizeFlow('Failed to submit bug report.');
    }
  }

  Future<void> _submitBundledFeedback() async {
    setState(() => _isBotTyping = true);
    try {
      await SupportService.instance.sendFeedback(
        userId: _userId!,
        type: _ticketDraft['feedback_type'],
        message: _ticketDraft['message'],
      );

      _finalizeFlow(
          "✨ *Feedback Wrapped*\nType: ${_ticketDraft['feedback_type']}\nMessage: ${_ticketDraft['message']}");
    } catch (e) {
      _finalizeFlow('Feedback failed to send.');
    }
  }

  void _finalizeFlow(String bundleSummaryText) {
    if (!mounted) return;
    setState(() => _isBotTyping = true);

    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (mounted) {
        setState(() {
          _transientMessages = [];
          _isBotTyping = false;
          _botFlowState = 'idle';
          _isManualInput = false;
        });

        await SupportService.instance.sendSupportMessage(
            userId: _userId!,
            text: bundleSummaryText,
            isFromAdmin: false, // User sends bot recap
            metadata: {'from_system': true});

        _addBotTransient('Great! Is there anything else I can do for you?', [
          {'label': 'View Active Tickets 🎫', 'action': 'view_tickets'},
          {'label': 'Chat with Team 🤝', 'action': 'talk_to_agent'},
          {'label': 'Return Home 🏠', 'action': 'back_to_menu'},
          {'label': 'Resolve & Clear ✨', 'action': 'issue_resolved'},
        ]);
      }
    });
  }

  // --- BOT TRANSIENT HELPERS ---

  void _addBotTransient(String text, [List<Map<String, dynamic>>? options]) {
    setState(() => _isBotTyping = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _transientMessages.add(Message(
            id: 'bot-${DateTime.now().ms}',
            senderId: 'admin',
            receiverId: _userId!,
            text: text,
            timestamp: DateTime.now(),
            status: MessageStatus.read,
            isEncrypted: false,
            metadata: options != null ? {'options': options} : null,
          ));
          _isBotTyping = false;
          _isManualInput = options == null;
        });
        _scrollToBottom();
      }
    });
  }

  void _simulateBotResponse() {
    _addBotTransient('I\'m here to help! 🔍 What would you like to do?', [
      {'label': 'Report a Bug 🐛', 'action': 'start_bug'},
      {'label': 'Open Support Ticket 🎫', 'action': 'start_ticket'},
      {'label': 'View My Tickets 🎫', 'action': 'view_tickets'},
      {'label': 'Share Feedback ✨', 'action': 'start_feedback'},
      {'label': 'Chat with Team 🤝', 'action': 'talk_to_agent'},
    ]);
  }

  Future<void> _handleBotAction(Map<String, dynamic> action) async {
    if (_isBotTyping) return;
    final act = action['action'];

    if (act == 'view_tickets') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const SupportTicketsScreen()));
    } else if (act == 'issue_resolved') {
      _resetChatSession();
    } else if (act == 'confirm_ticket') {
      _submitBundledTicket();
    } else if (act == 'confirm_bug') {
      _submitBundledBug();
    } else if (act == 'talk_to_agent') {
      // ESCALATION START - Request live chat
      await _requestLiveChat();
    } else if (act == 'start_ticket') {
      _addBotTransient('Select ticket category:', [
        {
          'label': 'Privacy & Encryption 🔐',
          'action': 'set_ticket_category',
          'value': 'Security'
        },
        {
          'label': 'Account & Discovery 👤',
          'action': 'set_ticket_category',
          'value': 'Social'
        },
        {
          'label': 'App Access Issues ⚙️',
          'action': 'set_ticket_category',
          'value': 'Technical'
        },
        {
          'label': 'General Help ❓',
          'action': 'set_ticket_category',
          'value': 'Other'
        },
      ]);
    } else if (act == 'start_bug') {
      _addBotTransient('Where did the bug occur?', [
        {
          'label': 'Lobby / Chats 💬',
          'action': 'set_bug_area',
          'value': 'Chat'
        },
        {
          'label': 'Discovery / Global 🔍',
          'action': 'set_bug_area',
          'value': 'Discovery'
        },
        {
          'label': 'Profile / Settings ⚙️',
          'action': 'set_bug_area',
          'value': 'Profile'
        },
      ]);
    } else if (act == 'set_bug_area') {
      _ticketDraft['area'] = action['value'];
      _addBotTransient('How serious is it?', [
        {'label': 'Low 🌱', 'action': 'set_bug_severity', 'value': 'low'},
        {'label': 'Medium ⚠️', 'action': 'set_bug_severity', 'value': 'medium'},
        {'label': 'High 🔥', 'action': 'set_bug_severity', 'value': 'high'},
      ]);
    } else if (act == 'set_ticket_category') {
      _ticketDraft['category'] = action['value'];
      _addBotTransient('Which part of the app?', [
        {
          'label': 'In-Chat Logic 🛡️',
          'action': 'set_ticket_loc',
          'value': 'In-Chat'
        },
        {
          'label': 'Friend Requests ➕',
          'action': 'set_ticket_loc',
          'value': 'Friends'
        },
        {
          'label': 'Profile Settings 👤',
          'action': 'set_ticket_loc',
          'value': 'Profile'
        },
      ]);
    } else if (act == 'set_ticket_loc') {
      _ticketDraft['location'] = action['value'];
      _botFlowState = 'collecting_ticket_title';
      _addBotTransient(
          'Understood. Please give this ticket a short title. 🏷️');
    } else if (act == 'set_bug_severity') {
      _ticketDraft['severity'] = action['value'];
      _botFlowState = 'collecting_bug_title';
      _addBotTransient('Briefly title the bug you found. 🐛');
    } else if (act == 'start_feedback') {
      _addBotTransient('What kind of feedback?', [
        {
          'label': 'Feature Request 💡',
          'action': 'set_feedback_type',
          'value': 'feature'
        },
        {
          'label': 'UX / UI Suggestion ✨',
          'action': 'set_feedback_type',
          'value': 'ux'
        },
      ]);
    } else if (act == 'set_feedback_type') {
      _ticketDraft['feedback_type'] = action['value'];
      _botFlowState = 'collecting_feedback_msg';
      _addBotTransient('Tell us more! What’s on your mind? 📝');
    } else if (act == 'back_to_menu') {
      setState(() {
        _isManualInput = false;
        _isBotTyping = true;
        _botFlowState = 'idle';
        _transientMessages = [];
      });
      _simulateBotResponse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        scaffoldBackgroundColor: Colors.white,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildMessagesList(),
                  if (_isBotTyping)
                    Positioned(
                        bottom: 12, left: 16, child: _buildTypingIndicator()),
                ],
              ),
            ),
            _buildModernInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Boofer is typing...',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueAccent,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    final bool isEscalated = _botFlowState == 'agent_esc';

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 10),
      child: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            UserAvatar(
                avatar: isEscalated ? '🤝' : '🤖',
                name: 'Support',
                radius: 18,
                isCompany: true),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text(isEscalated ? 'Human Agent' : 'Boofer',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, size: 16, color: Colors.green),
                ]),
                Text(isEscalated ? 'Live Teammate' : 'Support',
                    style: TextStyle(
                        fontSize: 11,
                        color: isEscalated ? Colors.blue : Colors.green)),
              ],
            ),
          ],
        ),
        actions: [
          if (isEscalated)
            TextButton.icon(
              onPressed: () => _handleBotAction({'action': 'back_to_menu'}),
              icon: const Icon(Icons.exit_to_app, size: 16),
              label: const Text('Exit Chat', style: TextStyle(fontSize: 12)),
            )
          else ...[
            IconButton(
                icon: const Icon(Icons.forum_outlined, color: Colors.blue),
                onPressed: () => _handleBotAction({'action': 'talk_to_agent'}),
                tooltip: 'Chat with Team'),
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _resetChatSession,
                tooltip: 'Reset Chat'),
            IconButton(
              icon: const Icon(Icons.confirmation_number_outlined,
                  size: 22, color: Colors.black54),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SupportTicketsScreen()));
              },
              tooltip: 'My Tickets',
            ),
          ],
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final List<Message> allMessages = [];
    final bool isInLiveChat = _botFlowState == 'agent_esc';
    final bool isPendingLiveChat = _botFlowState == 'agent_pending';

    // Initial Greeting (Internal only) - hide buttons if in live chat
    allMessages.add(Message(
        id: 'bot-welcome',
        senderId: 'admin',
        receiverId: _userId ?? '',
        text:
            'Hi! I\'m Boofer, your official support guide. 🛣️\n\nHow can I assist you today?',
        timestamp: DateTime.parse('2000-01-01'),
        status: MessageStatus.read,
        isEncrypted: false,
        metadata: isInLiveChat
            ? null
            : {
                'options': [
                  {'label': 'Report a Bug 🐛', 'action': 'start_bug'},
                  {'label': 'Open Support Ticket 🎫', 'action': 'start_ticket'},
                  {'label': 'Share Feedback ✨', 'action': 'start_feedback'},
                  {'label': 'Chat with Team 🤝', 'action': 'talk_to_agent'},
                ]
              }));

    // DB Messages (Syncing with Admin Dashboard)
    for (var msg in _dbMessages) {
      final isMe = !(msg['is_from_admin'] as bool);
      final metadata = msg['metadata'] != null
          ? Map<String, dynamic>.from(msg['metadata'] as Map)
          : null;
      
      // Remove options from metadata if in live chat mode
      Map<String, dynamic>? filteredMetadata;
      if (isInLiveChat && metadata != null) {
        filteredMetadata = Map<String, dynamic>.from(metadata);
        filteredMetadata.remove('options');
      } else {
        filteredMetadata = metadata;
      }

      allMessages.add(Message(
        id: msg['id']?.toString() ?? '',
        senderId: isMe ? (_userId ?? '') : 'admin',
        receiverId: isMe ? 'admin' : (_userId ?? ''),
        text: msg['text'] ?? '',
        timestamp: msg['timestamp'] != null
            ? DateTime.parse(msg['timestamp'])
            : DateTime.now(),
        status: MessageStatus.read,
        isEncrypted: false,
        metadata: filteredMetadata,
      ));
    }

    // Local Transient Messages (Drafting Flows) - filter options if in live chat
    allMessages.addAll(_transientMessages.map((msg) {
      if (isInLiveChat && msg.metadata != null && msg.metadata!.containsKey('options')) {
        return msg.copyWith(
          metadata: Map<String, dynamic>.from(msg.metadata!)..remove('options'),
        );
      }
      return msg;
    }));

    // Add pending status message if waiting for agent
    if (isPendingLiveChat) {
      allMessages.add(Message(
        id: 'pending-status',
        senderId: 'admin',
        receiverId: _userId ?? '',
        text: '⏳ Requesting live chat...\n\nWaiting for a support agent to accept your request.',
        timestamp: DateTime.now(),
        status: MessageStatus.read,
        isEncrypted: false,
        metadata: {'from_system': true},
      ));
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages[allMessages.length - 1 - index];
        final isMe = message.senderId == (_userId ?? '');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MessageBubble(
            message: message,
            currentUserId: _userId ?? '',
            senderName: isMe
                ? 'You'
                : (message.senderId == 'admin' ? 'Support' : 'Boofer'),
            onAction: _handleBotAction,
          ),
        );
      },
    );
  }

  Widget _buildModernInputArea() {
    if (!_isManualInput) return const SizedBox.shrink();
    return ModernChatInput(
      onSendMessage: _sendMessage,
      hideWarning: true, // Hide warning in support chat
    );
  }
}
