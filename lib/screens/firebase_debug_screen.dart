import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_test_service.dart';
import '../services/local_storage_service.dart';

class FirebaseDebugScreen extends StatefulWidget {
  @override
  _FirebaseDebugScreenState createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  String _output = 'Ready to run Firebase diagnostics...';
  bool _isRunning = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Debug'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _runFullDiagnostics,
                        child: Text('Run Full Diagnostics'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _runUserCreationTest,
                        child: Text('Test User Creation'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _resetAllData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Force Reset All Data'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _output,
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _runFullDiagnostics() async {
    setState(() {
      _isRunning = true;
      _output = 'Running full diagnostics...\n';
    });
    
    await _runDiagnostics();
    
    setState(() {
      _isRunning = false;
    });
  }
  
  void _runUserCreationTest() async {
    setState(() {
      _isRunning = true;
      _output = 'Running user creation test...\n';
    });
    
    await _testUserCreation();
    
    setState(() {
      _isRunning = false;
    });
  }

  void _resetAllData() async {
    setState(() {
      _isRunning = true;
      _output = 'Resetting all data...\n';
    });
    
    await _resetData();
    
    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runDiagnostics() async {
    _log('🔥 Starting Firebase Diagnostics...');
    
    try {
      _log('\n1️⃣ Testing Firebase Core...');
      await Firebase.initializeApp();
      _log('✅ Firebase Core initialized successfully');
      
      _log('\n2️⃣ Testing Firestore Connection...');
      final firestore = FirebaseFirestore.instance;
      
      _log('\n3️⃣ Testing Firebase Auth...');
      final auth = FirebaseAuth.instance;
      
      final authResult = await auth.signInAnonymously();
      final user = authResult.user;
      
      if (user != null) {
        _log('✅ Anonymous auth successful: ${user.uid}');
        
        _log('\n4️⃣ Testing Firestore Write...');
        
        final testData = {
          'id': user.uid,
          'handle': 'test_user_${DateTime.now().millisecondsSinceEpoch}',
          'virtualNumber': '+15551234567',
          'fullName': 'Test User',
          'bio': 'Test bio',
          'isDiscoverable': true,
          'status': 'online',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        
        await firestore.collection('users').doc(user.uid).set(testData);
        _log('✅ Firestore write successful');
        
        _log('\n5️⃣ Testing Firestore Read...');
        final doc = await firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          _log('✅ Firestore read successful');
          _log('📄 Document data: ${doc.data()}');
        } else {
          _log('❌ Document not found after write');
        }
        
        _log('\n6️⃣ Testing Firestore Query...');
        try {
          final query = await firestore
              .collection('users')
              .where('isDiscoverable', isEqualTo: true)
              .limit(1)
              .get();
          
          _log('✅ Simple query successful: ${query.docs.length} documents');
        } catch (e) {
          _log('⚠️ Query failed (may need index): $e');
        }
        
        _log('\n🧹 Cleaning up test data...');
        await firestore.collection('users').doc(user.uid).delete();
        _log('✅ Test data cleaned up');
        
      } else {
        _log('❌ Anonymous auth failed - no user returned');
      }
      
      _log('\n🎉 Firebase Diagnostics Complete!');
      
    } catch (e, stackTrace) {
      _log('❌ Firebase Diagnostics Failed: $e');
      _log('Stack trace: $stackTrace');
    }
  }
  
  Future<void> _testUserCreation() async {
    _log('👤 Testing User Creation Flow...');
    
    try {
      await Firebase.initializeApp();
      
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      final authResult = await auth.signInAnonymously();
      final user = authResult.user;
      
      if (user == null) {
        throw Exception('Failed to create anonymous user');
      }
      
      _log('✅ Anonymous user created: ${user.uid}');
      
      final userData = {
        'id': user.uid,
        'handle': 'debug_user',
        'virtualNumber': '+15559876543',
        'fullName': 'Debug User',
        'bio': 'Debug test user',
        'isDiscoverable': true,
        'status': 'online',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      int attempts = 0;
      bool success = false;
      
      while (attempts < 3 && !success) {
        attempts++;
        try {
          _log('📝 Write attempt $attempts...');
          
          await firestore.collection('users').doc(user.uid).set(userData);
          
          final doc = await firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            _log('✅ User profile created and verified');
            _log('📄 Profile data: ${doc.data()}');
            success = true;
          } else {
            _log('⚠️ Write appeared successful but document not found');
          }
          
        } catch (e) {
          _log('❌ Write attempt $attempts failed: $e');
          if (attempts < 3) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }
      
      if (!success) {
        _log('❌ All write attempts failed');
      }
      
      try {
        await firestore.collection('users').doc(user.uid).delete();
        _log('🧹 Test user cleaned up');
      } catch (e) {
        _log('⚠️ Cleanup failed: $e');
      }
      
    } catch (e, stackTrace) {
      _log('❌ User creation test failed: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  Future<void> _resetData() async {
    _log('🧹 Starting complete data reset...');
    
    try {
      // Use the local storage service to reset onboarding
      _log('Resetting onboarding data...');
      await LocalStorageService.clearOnboardingData();
      _log('✅ Onboarding data reset complete');
      
      // Reset Firebase Auth
      _log('Signing out from Firebase Auth...');
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      _log('✅ Firebase Auth signed out');
      
      // Clear test documents from Firestore
      _log('Cleaning up test documents...');
      final firestore = FirebaseFirestore.instance;
      try {
        final testDocs = await firestore.collection('test').get();
        for (final doc in testDocs.docs) {
          await doc.reference.delete();
        }
        _log('✅ Test documents cleaned up');
      } catch (e) {
        _log('⚠️ Failed to clean test documents: $e');
      }
      
      _log('🎉 Complete data reset finished!');
      _log('ℹ️ All local data cleared. Firebase user documents remain.');
      _log('ℹ️ You can now test fresh onboarding without conflicts.');
      
    } catch (e, stackTrace) {
      _log('❌ Data reset failed: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  void _log(String message) {
    setState(() {
      _output += '$message\n';
    });
    print(message);
  }
}