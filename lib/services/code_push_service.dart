import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CodePushService {
  static final CodePushService instance = CodePushService._internal();
  CodePushService._internal();

  final _updater = ShorebirdUpdater();
  bool _isChecking = false;

  Future<void> checkForUpdates(BuildContext context) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      debugPrint('🔍 [CodePush] Checking for updates...');

      // 1. Check Shorebird for new code
      final status = await _updater.checkForUpdate();
      debugPrint('🔍 [CodePush] Update status: $status');

      if (status == UpdateStatus.outdated) {
        // 2. Download and apply the patch
        debugPrint('下载 [CodePush] Downloading and applying patch...');
        await _updater.update();
        debugPrint('✅ [CodePush] Patch downloaded and applied');

        // 3. Consult Supabase: Is this a "Critical" fix?
        final res = await Supabase.instance.client
            .from('config')
            .select()
            .order('created_at', ascending: false)
            .limit(1)
            .single();

        final bool forceRestart = res['force_restart'] ?? false;
        final String patchNotes =
            res['patch_notes'] ??
            'We\'ve improved Boofer with some background fixes.';

        if (forceRestart) {
          _showUpdateDialog(context, patchNotes);
        } else {
          debugPrint('ℹ️ [CodePush] Patch will be applied on next restart');
        }
      }
    } catch (e) {
      debugPrint('❌ [CodePush] Error during update check: $e');
    } finally {
      _isChecking = false;
    }
  }

  void _showUpdateDialog(BuildContext context, String patchNotes) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Update Required',
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
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
                            color: Colors.blueAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.system_update_alt_rounded,
                            color: Colors.blueAccent,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Midnight Patch Available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          patchNotes,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () {
                            // Tip: Install 'restart_app' package and call 'Restart.restartApp()'
                            // to automatically apply the Shorebird patch.
                            debugPrint('🚀 [CodePush] User triggered restart');
                            // Close the app or restart it.
                            // For now, we'll suggest a restart or use a package like 'restart_app'.
                            // The simplest way to apply a Shorebird patch is a cold start.
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Update Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'App will restart to apply changes',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
