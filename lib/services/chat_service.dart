import 'dart:async';
import '../models/message_model.dart';
import '../models/network_state.dart';

abstract class IChatService {
  String? get currentUserId;
  Stream<List<Message>> get messagesStream;
  Stream<NetworkState> get networkState;
  NetworkMode get currentMode;
  Future<void> initialize(String userId);
  Future<void> sendMessage(String text);
  Future<void> switchMode(NetworkMode mode);
  Future<void> retryFailedMessages();
  void dispose();
}

class ChatService implements IChatService {
  static ChatService? _instance;
  static ChatService getInstance() => _instance ??= ChatService._internal();
  ChatService._internal();

  final StreamController<List<Message>> _messagesController = 
      StreamController<List<Message>>.broadcast();
  final StreamController<NetworkState> _networkStateController = 
      StreamController<NetworkState>.broadcast();
  
  final List<Message> _messages = [];
  int _messageIdCounter = 1;
  String? _currentUserId;
  NetworkMode _currentMode = NetworkMode.auto;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Stream<List<Message>> get messagesStream => _messagesController.stream;

  @override
  Stream<NetworkState> get networkState => _networkStateController.stream;

  @override
  NetworkMode get currentMode => _currentMode;
  
  List<Message> get messages => List.unmodifiable(_messages);

  @override
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    
    // Initialize network state
    _networkStateController.add(NetworkState.initial());
    
    // Add some demo messages
    _addDemoMessages();
  }

  void _addDemoMessages() {
    final demoMessages = [
      Message.create(
        text: "Welcome to Boofer! This is a demo message.",
        senderId: "system",
        isOffline: false,
        status: MessageStatus.delivered,
      ),
      Message.create(
        text: "You can switch between light and dark themes using the theme toggle button.",
        senderId: "system", 
        isOffline: false,
        status: MessageStatus.delivered,
      ),
      Message.create(
        text: "This is what your message looks like!",
        senderId: _currentUserId ?? "demo_user",
        isOffline: false,
        status: MessageStatus.sent,
      ),
    ];

    for (var message in demoMessages) {
      message.id = _messageIdCounter++;
      _messages.add(message);
    }
    
    _messagesController.add(_messages);
  }

  @override
  Future<void> sendMessage(String text) async {
    final message = Message.create(
      text: text,
      senderId: _currentUserId ?? "demo_user",
      isOffline: false,
      status: MessageStatus.pending,
    );
    
    message.id = _messageIdCounter++;
    _messages.add(message);
    _messagesController.add(_messages);

    // Simulate message being sent
    await Future.delayed(Duration(milliseconds: 500));
    message.status = MessageStatus.sent;
    _messagesController.add(_messages);

    // Simulate delivery
    await Future.delayed(Duration(milliseconds: 1000));
    message.status = MessageStatus.delivered;
    _messagesController.add(_messages);
  }

  @override
  Future<void> switchMode(NetworkMode mode) async {
    _currentMode = mode;
    // Update network state based on mode
    final currentState = NetworkState.initial();
    _networkStateController.add(currentState.copyWith(mode: mode));
  }

  @override
  Future<void> retryFailedMessages() async {
    // Find failed messages and retry them
    final failedMessages = _messages.where((m) => m.status == MessageStatus.failed).toList();
    for (var message in failedMessages) {
      message.status = MessageStatus.pending;
      _messagesController.add(_messages);
      
      await Future.delayed(Duration(milliseconds: 500));
      message.status = MessageStatus.sent;
      _messagesController.add(_messages);
      
      await Future.delayed(Duration(milliseconds: 500));
      message.status = MessageStatus.delivered;
      _messagesController.add(_messages);
    }
  }

  @override
  void dispose() {
    _messagesController.close();
    _networkStateController.close();
  }
}