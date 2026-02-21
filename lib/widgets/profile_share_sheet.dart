import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import '../models/user_model.dart' as app_user;
import '../providers/chat_provider.dart';
import '../services/user_service.dart';
import 'user_avatar.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileShareSheet extends StatefulWidget {
  final app_user.User? profileToShare;
  final String? sharedText;
  final bool isExternalFlow;

  final List<String>? sharedFiles;

  const ProfileShareSheet({
    super.key,
    this.profileToShare,
    this.sharedText,
    this.sharedFiles,
    this.isExternalFlow = false,
  });

  static void show(
    BuildContext context, {
    app_user.User? profile,
    String? text,
    List<String>? files,
    bool isExternal = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileShareSheet(
        profileToShare: profile,
        sharedText: text,
        sharedFiles: files,
        isExternalFlow: isExternal,
      ),
    );
  }

  @override
  State<ProfileShareSheet> createState() => _ProfileShareSheetState();
}

class _ProfileShareSheetState extends State<ProfileShareSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedRecipientIds = {};
  bool _isSending = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _sharableText {
    if (widget.sharedText != null) return widget.sharedText!;
    if (widget.profileToShare != null) {
      return "Check out ${widget.profileToShare!.fullName} (@${widget.profileToShare!.handle}) on Boofer!\n"
          "Virtual Number: ${widget.profileToShare!.virtualNumber}\n\n"
          "Join the secure & private messaging revolution on Boofer!";
    }
    return "Check out Boofer! The secure & private messaging app.";
  }

  void _shareToApp(String app) {
    final text = _sharableText;
    final encodedText = Uri.encodeComponent(text);
    const baseUrl = "https://boofer.chat";

    String url = '';
    switch (app) {
      case 'whatsapp':
        url = "whatsapp://send?text=$encodedText";
        break;
      case 'telegram':
        url = "tg://msg?text=$encodedText";
        break;
      case 'facebook':
        // Native app sharer with fallback to web
        url =
            "fb://facewebmodal/f?href=${Uri.encodeComponent("https://www.facebook.com/sharer/sharer.php?u=$baseUrl&quote=$text")}";
        break;
      case 'instagram':
        // Instagram direct sharing is limited; opening app is the best "direct" option
        url = "instagram://app";
        break;
      case 'x':
        url = "twitter://post?message=$encodedText";
        break;
    }

    if (url.isNotEmpty) {
      _launchUriWithFallback(url, text);
    }
  }

  Future<void> _launchUriWithFallback(
    String urlString,
    String fallbackText,
  ) async {
    final Uri url = Uri.parse(urlString);
    try {
      // Specialized handling for social apps
      if (urlString.startsWith('instagram://')) {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      }

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Precise web fallbacks
        if (urlString.startsWith('fb://')) {
          await launchUrl(
            Uri.parse(
              "https://www.facebook.com/sharer/sharer.php?u=https://boofer.chat&quote=${Uri.encodeComponent(fallbackText)}",
            ),
            mode: LaunchMode.externalApplication,
          );
        } else if (urlString.startsWith('twitter://')) {
          await launchUrl(
            Uri.parse(
              "https://twitter.com/intent/tweet?text=${Uri.encodeComponent(fallbackText)}",
            ),
            mode: LaunchMode.externalApplication,
          );
        } else {
          await Share.share(fallbackText);
        }
      }
    } catch (e) {
      debugPrint('Error launching URI: $e');
      await Share.share(fallbackText);
    }
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

    // Sorting: "You" first, then by activity (already sorted in ChatProvider, but let's be safe)
    filteredFriends.sort((a, b) {
      if (a.name == 'You') return -1;
      if (b.name == 'You') return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    return Container(
      // Dynamic height based on content
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // THIS SETS AUTO HEIGHT
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.isExternalFlow ? 'Share to Friends' : 'Share Content',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (_selectedRecipientIds.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedRecipientIds.clear()),
                    child: const Text('Clear Selection'),
                  ),
              ],
            ),
          ),

          // Shared Content Preview
          _buildSharedContentPreview(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Friends Section (Grid) - Only if search isn't active or results found
          if (filteredFriends.isNotEmpty)
            Flexible(
              child: GridView.builder(
                shrinkWrap: true, // Key for dynamic height
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) {
                  final friend = filteredFriends[index];
                  final isSelected = _selectedRecipientIds.contains(friend.id);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedRecipientIds.remove(friend.id);
                        } else {
                          _selectedRecipientIds.add(friend.id);
                        }
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            UserAvatar(
                              avatar: friend.avatar,
                              profilePicture: friend.profilePicture,
                              name: friend.name,
                              radius: 28,
                            ),
                            if (isSelected)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friend.name.split(' ').first,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (_searchQuery.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No friends found',
                style: TextStyle(color: Colors.grey),
              ),
            ),

          // Section Divider
          if (!widget.isExternalFlow)
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),

          // SHARING OPTIONS SECTION
          if (!widget.isExternalFlow)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'EXTERNAL OPTIONS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildCircularOption(
                          context,
                          icon: Icons.copy_all_rounded,
                          label: 'Copy',
                          color: Colors.grey.shade700,
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: _sharableText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Details copied!')),
                            );
                          },
                        ),
                        _buildCircularOption(
                          context,
                          icon: Icons.chat_bubble_outline,
                          svgUrl:
                              'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/whatsapp.svg',
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: () => _shareToApp('whatsapp'),
                        ),
                        _buildCircularOption(
                          context,
                          icon: Icons.camera_alt_outlined,
                          svgUrl:
                              'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/instagram.svg',
                          label: 'Instagram',
                          color: const Color(0xFFE4405F),
                          onTap: () => _shareToApp('instagram'),
                        ),
                        _buildCircularOption(
                          context,
                          icon: Icons.send_rounded,
                          svgUrl:
                              'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/telegram.svg',
                          label: 'Telegram',
                          color: const Color(0xFF0088CC),
                          onTap: () => _shareToApp('telegram'),
                        ),
                        _buildCircularOption(
                          context,
                          icon: Icons.close_rounded,
                          svgUrl:
                              'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/x.svg',
                          label: 'X',
                          color: Colors.black,
                          onTap: () => _shareToApp('x'),
                        ),
                        _buildCircularOption(
                          context,
                          icon: Icons.share_rounded,
                          label: 'Share',
                          color: theme.colorScheme.primary,
                          onTap: () {
                            Share.share(
                              _sharableText,
                              subject: 'Boofer Content',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Send Button (Internal) - Fixed at bottom if selection exists
          if (_selectedRecipientIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Send to ${_selectedRecipientIds.length} Friends',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            )
          else
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildCircularOption(
    BuildContext context, {
    required IconData icon,
    String? svgUrl,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: svgUrl != null
                  ? SvgPicture.network(
                      svgUrl,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      placeholderBuilder: (context) =>
                          Icon(icon, color: color, size: 24),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedContentPreview() {
    final theme = Theme.of(context);
    final hasText = widget.sharedText != null && widget.sharedText!.isNotEmpty;
    final hasFiles =
        widget.sharedFiles != null && widget.sharedFiles!.isNotEmpty;

    if (!hasText && !hasFiles) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFiles ? Icons.attachment : Icons.link,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Sharing Content',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (hasText) ...[
            const SizedBox(height: 8),
            Text(
              widget.sharedText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (hasFiles) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.sharedFiles!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = widget.sharedFiles![index];
                  final isImage =
                      path.toLowerCase().endsWith('.jpg') ||
                      path.toLowerCase().endsWith('.jpeg') ||
                      path.toLowerCase().endsWith('.png');

                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isImage
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : const Icon(Icons.insert_drive_file, size: 24),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    if (_selectedRecipientIds.isEmpty) return;

    setState(() => _isSending = true);
    debugPrint(
      '🚀 INTERNAL SHARE: Starting process for ${_selectedRecipientIds.length} recipients',
    );
    debugPrint(
      '📦 Content type: ${widget.profileToShare != null ? "Profile" : "Text/Files"}',
    );
    if (widget.profileToShare != null) {
      debugPrint('👤 Profile to share: @${widget.profileToShare!.handle}');
    } else if (widget.sharedText != null) {
      debugPrint('📝 Text length: ${widget.sharedText!.length}');
    }

    try {
      final chatProvider = context.read<ChatProvider>();
      final currentUser = await UserService.getCurrentUser();

      if (currentUser == null) {
        debugPrint('❌ Internal Share: Current user is NULL');
        throw Exception('User authentication failed. Please try again.');
      }
      debugPrint('👤 Sender ID: ${currentUser.id}');

      for (final recipientId in _selectedRecipientIds) {
        final conversationId = chatProvider.getConversationId(
          currentUser.id,
          recipientId,
        );

        debugPrint('📤 Sending to $recipientId (Conv: $conversationId)');

        final content = widget.profileToShare != null
            ? '👤 SHARED PROFILE\nName: ${widget.profileToShare!.fullName}\nHandle: @${widget.profileToShare!.handle}\nNumber: ${widget.profileToShare!.virtualNumber ?? "N/A"}'
            : (widget.sharedText ??
                  (widget.sharedFiles != null
                      ? 'Shared ${widget.sharedFiles!.length} files'
                      : 'Check this out!'));

        final type = widget.sharedFiles != null
            ? MessageType.image
            : MessageType.text;

        final metadata = widget.sharedFiles != null
            ? {'local_paths': widget.sharedFiles}
            : (widget.profileToShare != null
                  ? {'profile_id': widget.profileToShare!.id}
                  : null);

        await chatProvider.sendMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          receiverId: recipientId,
          content: content,
          type: type,
          metadata: metadata,
        );
        debugPrint('✅ Message sent to $recipientId');
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final count = _selectedRecipientIds.length;
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Successfully shared with $count friends!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Internal Share ERROR: $e');
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
}

extension on ChatProvider {
  String getConversationId(String u1, String u2) {
    final ids = [u1, u2];
    ids.sort();
    return 'conv_${ids[0]}_${ids[1]}';
  }
}
