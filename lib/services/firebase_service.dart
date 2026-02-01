import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../core/error/error_handler.dart';
import '../core/models/app_error.dart';

/// Firebase service for real-time messaging and user management
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._internal();
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Stream controllers for real-time updates
  final StreamController<List<Message>> _messagesController = StreamController<List<Message>>.broadcast();
  final StreamController<List<User>> _usersController = StreamController<List<User>>.broadcast();
  
  Stream<List<Message>> get messagesStream => _messagesController.stream;
  Stream<List<User>> get usersStream => _usersController.stream;

  /// Initialize Firebase connection
  Future<void> initialize() async {
    try {
      // Firebase is initialized in main.dart with Firebase.initializeApp()
      print('Firebase service initialized');
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to initialize Firebase: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  /// Create user account with virtual number and verify storage
  Future<User?> createUser({
    required String virtualNumber,
    required String handle,
    required String fullName,
    String bio = '',
  }) async {
    try {
      print('🔄 Creating Firebase user...');
      
      // Create anonymous auth user (no email/password needed for privacy)
      final authResult = await _auth.signInAnonymously();
      final firebaseUser = authResult.user;
      
      if (firebaseUser == null) {
        print('❌ Failed to create anonymous Firebase user');
        throw Exception('Failed to create anonymous user');
      }

      print('✅ Anonymous Firebase user created: ${firebaseUser.uid}');

      // Wait for auth to fully initialize
      await Future.delayed(const Duration(milliseconds: 2000));

      final user = User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? 'unknown@firebase.com',
        virtualNumber: virtualNumber,
        handle: handle,
        fullName: fullName,
        bio: bio,
        isDiscoverable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: UserStatus.online,
      );

      print('🔄 Saving user profile to Firestore...');

      // Create users collection if it doesn't exist
      final userData = {
        'id': user.id,
        'virtualNumber': user.virtualNumber,
        'handle': user.handle.toLowerCase(),
        'fullName': user.fullName,
        'bio': user.bio,
        'isDiscoverable': user.isDiscoverable,
        'status': user.status.toString().split('.').last,
        'createdAt': user.createdAt.toIso8601String(),
        'updatedAt': user.updatedAt.toIso8601String(),
      };
      
      print('🔄 User data to save: $userData');
      
      // Force create the document
      await _firestore.collection('users').doc(user.id).set(userData);
      
      // Wait and verify the document was created
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final verifyDoc = await _firestore.collection('users').doc(user.id).get();
      if (!verifyDoc.exists) {
        throw Exception('User document not found after creation - Firestore may not be properly configured');
      }
      
      final savedData = verifyDoc.data();
      print('✅ User profile verified in Firestore: $savedData');
      
      return user;
    } catch (e, stackTrace) {
      print('❌ Firebase user creation failed: $e');
      print('❌ Stack trace: $stackTrace');
      
      // Clean up auth user if profile creation failed
      try {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
          print('🧹 Cleaned up failed auth user');
        }
      } catch (cleanupError) {
        print('⚠️ Failed to cleanup auth user: $cleanupError');
      }
      
      _errorHandler.handleError(AppError.service(
        message: 'Failed to create user: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Verify user exists in Firestore
  Future<bool> verifyUserExists(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final exists = doc.exists;
      print('🔍 User verification for $userId: ${exists ? 'EXISTS' : 'NOT FOUND'}');
      if (exists) {
        print('📄 User data: ${doc.data()}');
      }
      return exists;
    } catch (e) {
      print('❌ Failed to verify user exists: $e');
      return false;
    }
  }

  /// Test Firestore connection
  Future<bool> testFirestoreConnection() async {
    try {
      print('🔄 Testing Firestore connection...');
      
      // Try to write a test document
      final testDoc = _firestore.collection('test').doc('connection_test');
      await testDoc.set({
        'timestamp': DateTime.now().toIso8601String(),
        'test': true,
      });
      
      // Try to read it back
      final doc = await testDoc.get();
      if (doc.exists) {
        // Clean up test document
        await testDoc.delete();
        print('✅ Firestore connection test successful');
        return true;
      } else {
        print('❌ Firestore connection test failed - document not found');
        return false;
      }
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      return false;
    }
  }

  /// Get current user
  Future<User?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) return null;

      return User.fromJson(doc.data()!);
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get current user: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Search users globally
  Future<List<User>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      // Search by handle or virtual number
      final handleQuery = await _firestore
          .collection('users')
          .where('handle', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('handle', isLessThan: query.toLowerCase() + '\uf8ff')
          .where('isDiscoverable', isEqualTo: true)
          .limit(20)
          .get();

      final numberQuery = await _firestore
          .collection('users')
          .where('virtualNumber', isGreaterThanOrEqualTo: query)
          .where('virtualNumber', isLessThan: query + '\uf8ff')
          .where('isDiscoverable', isEqualTo: true)
          .limit(20)
          .get();

      final users = <User>[];
      final seenIds = <String>{};

      // Combine results and remove duplicates
      for (final doc in [...handleQuery.docs, ...numberQuery.docs]) {
        if (!seenIds.contains(doc.id)) {
          users.add(User.fromJson(doc.data()));
          seenIds.add(doc.id);
        }
      }

      return users;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to search users: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Send message with real-time updates
  Future<Message?> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    try {
      final message = Message.create(
        text: text,
        senderId: senderId,
        receiverId: receiverId,
        conversationId: conversationId,
        type: type,
      );

      // Save to Firestore
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(message.id)
          .set(message.toJson());

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [senderId, receiverId],
        'lastMessage': text,
        'lastMessageTime': message.timestamp.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return message;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send message: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Listen to messages in real-time
  StreamSubscription<QuerySnapshot>? listenToMessages(String conversationId) {
    try {
      return _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen((snapshot) {
        final messages = snapshot.docs
            .map((doc) => Message.fromJson(doc.data()))
            .toList();
        _messagesController.add(messages);
      });
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to listen to messages: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return null;
    }
  }

  /// Get user conversations
  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get conversations: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Send connection request
  Future<bool> sendConnectionRequest({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) async {
    try {
      final requestId = '${fromUserId}_${toUserId}_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('connection_requests').doc(requestId).set({
        'id': requestId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'message': message ?? 'Hi! I\'d like to connect with you.',
        'status': 'pending',
        'sentAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to send connection request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Get pending connection requests
  Future<List<Map<String, dynamic>>> getConnectionRequests(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to get connection requests: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return [];
    }
  }

  /// Accept/decline connection request
  Future<bool> respondToConnectionRequest({
    required String requestId,
    required bool accept,
  }) async {
    try {
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': accept ? 'accepted' : 'declined',
        'respondedAt': DateTime.now().toIso8601String(),
      });

      if (accept) {
        // Add to friends collection for both users
        final request = await _firestore.collection('connection_requests').doc(requestId).get();
        final data = request.data()!;
        
        final batch = _firestore.batch();
        
        // Add friendship for both users
        batch.set(_firestore.collection('friends').doc(), {
          'userId': data['fromUserId'],
          'friendId': data['toUserId'],
          'status': 'accepted',
          'createdAt': DateTime.now().toIso8601String(),
        });
        
        batch.set(_firestore.collection('friends').doc(), {
          'userId': data['toUserId'],
          'friendId': data['fromUserId'],
          'status': 'accepted',
          'createdAt': DateTime.now().toIso8601String(),
        });
        
        await batch.commit();
      }

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.service(
        message: 'Failed to respond to connection request: $e',
        stackTrace: stackTrace,
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      return false;
    }
  }

  /// Sign out from Firebase
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ Firebase user signed out successfully');
    } catch (e) {
      print('❌ Firebase signout failed: $e');
      throw Exception('Failed to sign out from Firebase: $e');
    }
  }

  void dispose() {
    _messagesController.close();
    _usersController.close();
  }
}