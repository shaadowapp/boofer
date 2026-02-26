import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class CodePushService {
  static final CodePushService instance = CodePushService._internal();
  CodePushService._internal();

  final _updater = ShorebirdUpdater();
  bool _isChecking = false;
  static const int _notificationId = 888;

  // Track status for UI
  final ValueNotifier<bool> isUpdateReady = ValueNotifier<bool>(false);
  final ValueNotifier<UpdateStatus> updateStatus = ValueNotifier<UpdateStatus>(UpdateStatus.upToDate);
  final ValueNotifier<int?> currentPatch = ValueNotifier<int?>(null);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// Returns true if the app is running with Shorebird engine (Release mode)
  Future<bool> get isShorebirdAvailable async => _updater.isAvailable;

  /// Refreshes the current patch number logic
  Future<void> syncPatchInfo() async {
    try {
      final patch = await _updater.readCurrentPatch();
      currentPatch.value = patch?.number;
      debugPrint('🔍 [CodePush] Current Patch Level: ${currentPatch.value ?? "Base"}');
    } catch (e) {
      debugPrint('⚠️ [CodePush] Failed to read patch info: $e');
    }
  }

  Future<void> checkForUpdates(BuildContext context) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      debugPrint('🔍 [CodePush] Starting deep update check...');
      lastError.value = null;
      
      // 1. Sync current state
      await syncPatchInfo();

      final available = await _updater.isAvailable;
      if (!available) {
        debugPrint('⚠️ [CodePush] Shorebird engine not available in this build (Debug/Profile mode?)');
        updateStatus.value = UpdateStatus.unavailable;
        return;
      }

      // 2. Check Shorebird for new code
      debugPrint('📡 [CodePush] Requesting Shorebird servers for version 1.0.0+6...');
      final status = await _updater.checkForUpdate();
      debugPrint('🔍 [CodePush] Shorebird check result: $status');
      updateStatus.value = status;

      if (status == UpdateStatus.outdated) {
        // ... rest of the code ...
        // Ensure we can show notifications
        await NotificationService.instance.checkPermission();

        // Notify user that download is starting
        debugPrint('🔍 [CodePush] New update detected. Starting download...');

        await NotificationService.instance.showProgressNotification(
          id: _notificationId,
          title: 'Updating Boofer',
          body: 'Downloading latest features and fixes...',
          progress: 0,
          maxProgress: 100,
          indeterminate: true,
        );

        // 3. Download and apply the patch (Wait for it)
        await _updater.update().timeout(const Duration(minutes: 5));
        
        // Sync info AFTER update attempt to see what changed
        await syncPatchInfo();
        
        debugPrint('✅ [CodePush] Patch downloaded and applied (pending restart)');

        // Mark update as ready for UI reflection
        isUpdateReady.value = true;
        updateStatus.value = UpdateStatus.restartRequired;

        // 4. Update notification to indicate readiness
        await NotificationService.instance.showSystemNotification(
          title: 'Update Ready ✨',
          body: 'The latest version of Boofer is ready. Restart now to apply.',
          payload: 'restart_required',
        );
        // ... (Supabase part unchanged) ...
        try {
          final res = await Supabase.instance.client
              .from('config')
              .select()
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (res != null) {
            final bool forceRestart = res['force_restart'] ?? false;
            final String patchNotes = res['patch_notes'] ?? 'We\'ve improved Boofer with some background fixes.';

            if (forceRestart && context.mounted) {
              _showUpdateDialog(context, patchNotes);
            }
          }
        } catch (e) {
          debugPrint('⚠️ [CodePush] Supabase config check failed: $e');
        }
      } else if (status == UpdateStatus.upToDate) {
        debugPrint('✅ [CodePush] App is already on the latest patch.');
      } else if (status == UpdateStatus.unavailable) {
        debugPrint('⚠️ [CodePush] Shorebird check unavailable.');
      }
    } catch (e) {
      debugPrint('❌ [CodePush] Critical Error during update check: $e');
      lastError.value = e.toString().contains('SocketException') 
          ? "No internet or Shorebird servers unreachable." 
          : "Unexpected Error: $e";
    } finally {
      await NotificationService.instance.cancelNotification(_notificationId);
      _isChecking = false;
    }
  }

  void _showUpdateDialog(BuildContext context, String patchNotes) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Update Required',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.cyanAccent,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Universal Patch Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      patchNotes,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          debugPrint('🚀 [CodePush] Restarting app...');
                          exit(0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: Colors.cyanAccent.withOpacity(0.4),
                        ),
                        child: const Text(
                          'RESTART NOW',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'New code is ready. Instantly apply the fix.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }
}
