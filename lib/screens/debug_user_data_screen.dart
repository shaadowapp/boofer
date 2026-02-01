import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/local_storage_service.dart';
import '../services/user_service.dart';
import '../services/google_auth_service.dart';

class DebugUserDataScreen extends StatefulWidget {
  const DebugUserDataScreen({super.key});

  @override
  State<DebugUserDataScreen> createState() => _DebugUserDataScreenState();
}

class _DebugUserDataScreenState extends State<DebugUserDataScreen> {
  Map<String, dynamic> debugData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = <String, dynamic>{};

      // Firebase Auth data
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      data['firebase_auth'] = {
        'uid': firebaseUser?.uid,
        'email': firebaseUser?.email,
        'displayName': firebaseUser?.displayName,
        'photoURL': firebaseUser?.photoURL,
        'isSignedIn': firebaseUser != null,
      };

      // Local Storage data
      data['local_storage'] = {
        'custom_user_id': await LocalStorageService.getString('custom_user_id'),
        'firebase_to_custom_id': await LocalStorageService.getString('firebase_to_custom_id'),
        'firebase_uid': await LocalStorageService.getString('firebase_uid'),
        'user_email': await LocalStorageService.getString('user_email'),
        'current_user': await LocalStorageService.getString('current_user'),
        'profile_completed': await LocalStorageService.getString('profile_completed'),
        'registered_emails': await LocalStorageService.getStringList('registered_emails'),
      };

      // UserService data
      final currentUser = await UserService.getCurrentUser();
      data['user_service'] = {
        'current_user_exists': currentUser != null,
        'user_id': currentUser?.id,
        'user_name': currentUser?.fullName,
        'user_handle': currentUser?.handle,
        'user_email': currentUser?.email,
        'virtual_number': currentUser?.virtualNumber,
        'created_at': currentUser?.createdAt.toIso8601String(),
        'updated_at': currentUser?.updatedAt.toIso8601String(),
      };

      // Firestore data
      if (firebaseUser != null) {
        final customUserId = await LocalStorageService.getString('custom_user_id');
        if (customUserId != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(customUserId)
                .get();
            
            data['firestore'] = {
              'document_exists': doc.exists,
              'document_id': customUserId,
              'document_data': doc.exists ? doc.data() : null,
            };
          } catch (e) {
            data['firestore'] = {
              'error': e.toString(),
            };
          }
        } else {
          data['firestore'] = {
            'error': 'No custom user ID found',
          };
        }
      }

      setState(() {
        debugData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        debugData = {'error': e.toString()};
        isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug User Data'),
        actions: [
          IconButton(
            onPressed: _loadDebugData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fix Profile Button
                  if (debugData['firebase_auth']?['isSignedIn'] == true &&
                      debugData['local_storage']?['custom_user_id'] == null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  'PROFILE ISSUE DETECTED',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You are signed in with Firebase but have no local user data. This usually happens when the profile creation failed during signup.',
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fixUserProfile,
                              icon: const Icon(Icons.build),
                              label: const Text('Fix Profile Data'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _resetProfileCompletion,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset Profile Modal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _clearAllData,
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Clear All Data'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  ...debugData.entries.map((entry) => _buildSection(entry.key, entry.value)),
                ],
              ),
            ),
    );
  }

  Future<void> _clearAllData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will sign you out and clear all local data. You will need to sign in again. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clearing all data...')),
        );

        // Clear UserService data
        await UserService.clearUserData();
        
        // Sign out from Google Auth and Firebase
        final googleAuthService = GoogleAuthService();
        await googleAuthService.signOut();
        
        // Clear all local storage
        await LocalStorageService.remove('custom_user_id');
        await LocalStorageService.remove('firebase_to_custom_id');
        await LocalStorageService.remove('firebase_uid');
        await LocalStorageService.remove('user_email');
        await LocalStorageService.remove('user_type');
        await LocalStorageService.remove('profile_completed');
        await LocalStorageService.remove('current_user');
        await LocalStorageService.remove('registered_emails');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared! Please restart the app and sign in again.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Reload debug data to show cleared state
        await _loadDebugData();
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fixUserProfile() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fixing profile data...')),
      );

      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final googleAuthService = GoogleAuthService();
        
        // Try to restore or recreate user session
        final restoredUser = await googleAuthService.restoreUserSession();
        
        if (restoredUser != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile data restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload debug data
          await _loadDebugData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not restore profile. You may need to sign out and sign in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fixing profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSection(String title, dynamic data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(data.toString()),
                  icon: const Icon(Icons.copy, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data is Map<String, dynamic>)
              ...data.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${entry.key}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        entry.value?.toString() ?? 'null',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: entry.value == null 
                              ? Colors.grey 
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
            else
              SelectableText(
                data?.toString() ?? 'null',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }

  /// Reset profile completion status for testing
  Future<void> _resetProfileCompletion() async {
    try {
      // Reset local storage flags
      await LocalStorageService.setString('profile_completed', 'false');
      await LocalStorageService.setString('user_type', 'incomplete_user');
      await LocalStorageService.remove('profile_modal_last_dismissed');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile completion status reset. Restart app to see modal.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload debug data
      _loadDebugData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset profile completion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}