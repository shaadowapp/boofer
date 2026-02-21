import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/multi_account_storage_service.dart';
import '../providers/auth_state_provider.dart';
import 'user_avatar.dart';
import '../screens/signup_steps_screen.dart';

class FastProfileSwitcher extends StatefulWidget {
  final bool showAddButton;

  const FastProfileSwitcher({super.key, this.showAddButton = true});

  static Future<void> show(BuildContext context, {bool showAddButton = true}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FastProfileSwitcher(showAddButton: showAddButton),
    );
  }

  @override
  State<FastProfileSwitcher> createState() => _FastProfileSwitcherState();
}

class _FastProfileSwitcherState extends State<FastProfileSwitcher> {
  List<Map<String, dynamic>> _accounts = [];
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await MultiAccountStorageService.getSavedAccounts();
    final currentId = context.read<AuthStateProvider>().currentUserId;
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _currentUserId = currentId;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSwitch(String id) async {
    if (id == _currentUserId) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context); // Close sheet first

    // Show a small loading overlay or handle it in AuthStateProvider
    await context.read<AuthStateProvider>().switchAccount(id);

    // AuthStateProvider.switchAccount usually triggers a navigation to /main,
    // which is fine since we are already on MainScreen, it effectively refreshes it.
  }

  void _handleAddAccount() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupStepsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Switch Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final isCurrent = account['id'] == _currentUserId;
                    final isPrimary = account['isPrimary'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _handleSwitch(account['id']),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : isPrimary
                                  ? theme.colorScheme.primary.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: isCurrent
                                ? theme.colorScheme.primary.withOpacity(0.05)
                                : isPrimary
                                ? theme.colorScheme.primary.withOpacity(0.02)
                                : isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  UserAvatar(
                                    avatar: account['avatar'],
                                    name:
                                        account['fullName'] ??
                                        account['handle'],
                                    radius: 24,
                                  ),
                                  if (isPrimary)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF1A1A2E)
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.workspace_premium,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          account['fullName'] ??
                                              account['handle'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isCurrent
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                        if (isPrimary) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '@${account['handle']}',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (widget.showAddButton) ...[
              const Divider(height: 1),
              ListTile(
                onTap: _handleAddAccount,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: const Text(
                  'Add Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
