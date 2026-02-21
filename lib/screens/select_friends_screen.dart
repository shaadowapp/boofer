import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../services/user_service.dart';
import '../widgets/user_avatar.dart';

class SelectFriendsScreen extends StatefulWidget {
  final String? sharedText;
  final List<String>? sharedFiles;

  const SelectFriendsScreen({super.key, this.sharedText, this.sharedFiles});

  @override
  State<SelectFriendsScreen> createState() => _SelectFriendsScreenState();
}

class _SelectFriendsScreenState extends State<SelectFriendsScreen> {
  final Set<String> _selectedFriendIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_selectedFriendIds.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final chatProvider = context.read<ChatProvider>();
      final currentUser = await UserService.getCurrentUser();

      if (currentUser == null) {
        throw Exception('User authentication failed. Please log in again.');
      }

      final count = _selectedFriendIds.length;
      debugPrint('🚀 External Share: Sending to $count recipients');

      for (final friendId in _selectedFriendIds) {
        final conversationId = _getConversationId(currentUser.id, friendId);

        final content =
            widget.sharedText ??
            (widget.sharedFiles != null
                ? 'Shared ${widget.sharedFiles!.length} files'
                : 'Checked this out on Boofer!');

        final type = widget.sharedFiles != null
            ? MessageType.image
            : MessageType.text;
        final metadata = widget.sharedFiles != null
            ? {'local_paths': widget.sharedFiles}
            : null;

        await chatProvider.sendMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          receiverId: friendId,
          content: content,
          type: type,
          metadata: metadata,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully shared with $count friends!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ External Share Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _getConversationId(String u1, String u2) {
    final ids = [u1, u2];
    ids.sort();
    return 'conv_${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = context.watch<ChatProvider>();
    final friends = chatProvider.allShareableFriends;

    final filteredFriends = friends.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.handle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to Friends'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: chatProvider.isLoadingFromNetwork && friends.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filteredFriends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No friends available to share with'
                        : 'No friends match your search',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];
                final isSelected = _selectedFriendIds.contains(friend.id);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedFriendIds.add(friend.id);
                      } else {
                        _selectedFriendIds.remove(friend.id);
                      }
                    });
                  },
                  secondary: UserAvatar(
                    avatar: friend.avatar,
                    profilePicture: friend.profilePicture,
                    name: friend.name,
                    radius: 24,
                  ),
                  title: Text(
                    friend.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('@${friend.handle}'),
                  activeColor: theme.colorScheme.primary,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
      floatingActionButton: _selectedFriendIds.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSending ? null : _handleSend,
              label: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Send to ${_selectedFriendIds.length}'),
              icon: _isSending ? null : const Icon(Icons.send),
            ),
    );
  }
}
