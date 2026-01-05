// Stub online service for demo purposes
import 'dart:async';
import '../models/message_model.dart';

abstract class IOnlineService {
  Future<void> initialize(String supabaseUrl, String supabaseKey);
  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendMessage(Message message);
  Stream<Message> get messageStream;
  bool get isConnected;
  void dispose();
}

class OnlineService implements IOnlineService {
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  bool _isConnected = false;

  @override
  Future<void> initialize(String supabaseUrl, String supabaseKey) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> connect() async {
    _isConnected = true;
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> sendMessage(Message message) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void dispose() {
    _messageController.close();
  }
}