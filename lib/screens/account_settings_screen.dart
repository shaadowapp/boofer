import 'package:flutter/material.dart';
import '../services/unified_storage_service.dart';
import '../services/supabase_service.dart';

import '../models/user_model.dart';
import '../widgets/user_avatar.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await SupabaseService.instance.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Account'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildInfoCard(theme),
                  const SizedBox(height: 24),
                  _buildDangerZone(theme),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: UserAvatar(
              avatar: _currentUser?.avatar,
              profilePicture: _currentUser?.profilePicture,
              name: _currentUser?.fullName ?? _currentUser?.handle,
              radius: 48,
              fontSize: 40,
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentUser?.displayName ?? 'User',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (_currentUser?.isVerified == true) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.verified,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _currentUser?.formattedHandle ?? '@username',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_currentUser?.virtualNumber != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentUser!.virtualNumber!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'ACCOUNT ACTIONS',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              _buildActionTile(
                theme,
                icon: Icons.ac_unit_rounded,
                title: 'Freeze Account',
                subtitle: 'Hide your account temporarily',
                onTap: _handleFreezeAccount,
                color: Colors.blue,
              ),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
              _buildActionTile(
                theme,
                icon: Icons.timer_off_outlined,
                title: 'Temporary Delete',
                subtitle: 'Deactivate account (recoverable)',
                onTap: _handleTemporaryDelete,
                color: Colors.orange,
              ),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
              _buildActionTile(
                theme,
                icon: Icons.delete_forever_rounded,
                title: 'Permanent Delete',
                subtitle: 'Erase all data permanently',
                onTap: _handlePermanentDelete,
                color: theme.colorScheme.error,
                isDangerous: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    bool isDangerous = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDangerous
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFreezeAccount() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Freeze Account?',
      content:
          'Your account will be hidden from other users. You will not receive notifications. You can reactivate your account anytime by logging back in.',
      confirmText: 'Freeze Account',
      isDangerous: false,
    );

    if (confirmed == true) {
      _performAccountAction(() async {
        await SupabaseService.instance.updateUserStatus('frozen');
        await SupabaseService.instance.signOut();
      });
    }
  }

  Future<void> _handleTemporaryDelete() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Temporarily Delete?',
      content:
          'Your account will be deactivated. You can recover it within 30 days by logging in. After 30 days, it will be permanently deleted.',
      confirmText: 'Deactivate',
      isDangerous: true,
    );

    if (confirmed == true) {
      _performAccountAction(() async {
        await SupabaseService.instance.deleteUserAccount(permanent: false);
      });
    }
  }

  Future<void> _handlePermanentDelete() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Permanently Delete?',
      content:
          'This action cannot be undone. All your chats, messages, media, and contacts will be permanently erased from our servers and your device.',
      confirmText: 'Delete Forever',
      isDangerous: true,
    );

    if (confirmed == true) {
      _performAccountAction(() async {
        // Clear local storage first
        await UnifiedStorageService.clearAll();
        await SupabaseService.instance.deleteUserAccount(permanent: true);
      });
    }
  }

  Future<void> _performAccountAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        // Navigate to login or initial screen
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required bool isDangerous,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDangerous
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
