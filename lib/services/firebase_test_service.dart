import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Simple Firebase test service to verify connection and authentication
class FirebaseTestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Test complete Firebase flow: auth + write + read
  static Future<Map<String, dynamic>> testCompleteFlow() async {
    final results = <String, dynamic>{
      'authTest': false,
      'writeTest': false,
      'readTest': false,
      'error': null,
    };

    try {
      print('🧪 Starting Firebase complete flow test...');

      // Step 1: Test authentication
      print('🔄 Testing Firebase Auth...');
      final authResult = await _auth.signInAnonymously();
      if (authResult.user != null) {
        results['authTest'] = true;
        print('✅ Auth test passed: ${authResult.user!.uid}');
      } else {
        throw Exception('Auth user is null');
      }

      // Wait for auth to be fully established
      await Future.delayed(const Duration(milliseconds: 2000));

      // Step 2: Test write operation
      print('🔄 Testing Firestore write...');
      final testDoc = _firestore.collection('test').doc('flow_test');
      await testDoc.set({
        'userId': authResult.user!.uid,
        'timestamp': Timestamp.now(),
        'testData': 'Firebase flow test',
      });
      results['writeTest'] = true;
      print('✅ Write test passed');

      // Step 3: Test read operation
      print('🔄 Testing Firestore read...');
      final doc = await testDoc.get();
      if (doc.exists && doc.data() != null) {
        results['readTest'] = true;
        print('✅ Read test passed: ${doc.data()}');
      } else {
        throw Exception('Document not found after write');
      }

      // Cleanup
      await testDoc.delete();
      await _auth.signOut();

      print('✅ Complete Firebase flow test successful!');
      return results;

    } catch (e) {
      print('❌ Firebase flow test failed: $e');
      results['error'] = e.toString();
      
      // Cleanup on error
      try {
        await _firestore.collection('test').doc('flow_test').delete();
        await _auth.signOut();
      } catch (cleanupError) {
        print('⚠️ Cleanup failed: $cleanupError');
      }
      
      return results;
    }
  }

  /// Test just authentication
  static Future<bool> testAuth() async {
    try {
      print('🧪 Testing Firebase Auth only...');
      final result = await _auth.signInAnonymously();
      if (result.user != null) {
        print('✅ Auth test passed: ${result.user!.uid}');
        await _auth.signOut();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Auth test failed: $e');
      return false;
    }
  }

  /// Test just Firestore connection (no auth required)
  static Future<bool> testFirestoreConnection() async {
    try {
      print('🧪 Testing Firestore connection...');
      
      // Test accessing Firestore settings (no auth required)
      await _firestore.settings;
      print('✅ Firestore connection test passed');
      return true;
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      return false;
    }
  }
}