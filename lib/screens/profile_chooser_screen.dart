import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/multi_account_storage_service.dart';
import '../providers/auth_state_provider.dart';
import '../widgets/user_avatar.dart';

class ProfileChooserScreen extends StatefulWidget {
  const ProfileChooserScreen({super.key});

  @override
  State<ProfileChooserScreen> createState() => _ProfileChooserScreenState();
}

class _ProfileChooserScreenState extends State<ProfileChooserScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await MultiAccountStorageService.getSavedAccounts();
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  Future<void> _handleSelect(String id) async {
    setState(() => _isLoading = true);
    try {
      await context.read<AuthStateProvider>().switchAccount(id);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to login: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a profile to continue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];

                      // Primary logic: explicitly true OR (no explicit primary exists AND index is 0)
                      final hasExplicitPrimary = _accounts.any(
                        (a) => a['isPrimary'] == true,
                      );
                      final isPrimary =
                          account['isPrimary'] == true ||
                          (!hasExplicitPrimary && index == 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Stack(
                            children: [
                              UserAvatar(
                                avatar: account['avatar'],
                                name: account['fullName'] ?? account['handle'],
                                radius: 28,
                                isCompany:
                                    account['is_company'] == true ||
                                    account['isCompany'] == true,
                              ),
                              if (isPrimary)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0F0F1A),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account['fullName'] ?? account['handle'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isPrimary)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF845EF7,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF845EF7,
                                      ).withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'PRIMARY',
                                    style: TextStyle(
                                      color: Color(0xFF845EF7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            isPrimary
                                ? 'Master Identity'
                                : 'Subordinate Profile',
                            style: TextStyle(
                              color: isPrimary
                                  ? const Color(0xFF845EF7)
                                  : Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white24,
                          ),
                          onTap: () => _handleSelect(account['id']),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
