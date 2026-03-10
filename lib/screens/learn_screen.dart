import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────

class _WikiArticle {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final List<_ArticleSection> sections;

  const _WikiArticle({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.sections,
  });
}

class _ArticleSection {
  final String heading;
  final String body;
  final String? tip;
  final List<_StepItem>? steps;

  const _ArticleSection({
    required this.heading,
    required this.body,
    this.tip,
    this.steps,
  });
}

class _StepItem {
  final String label;
  final String description;
  const _StepItem(this.label, this.description);
}

// ─────────────────────────────────────────────
// WIKI DATA
// ─────────────────────────────────────────────

const List<_WikiArticle> _wikiArticles = [
  // 1 ─ Getting Started
  _WikiArticle(
    id: 'getting-started',
    emoji: '🚀',
    title: 'Getting Started',
    subtitle: 'Your first steps inside Boofer',
    color: Color(0xFF6366F1),
    sections: [
      _ArticleSection(
        heading: 'Welcome to Boofer',
        body:
            'Boofer is a privacy-first messaging app made in India. When you sign up you receive a unique Virtual Number — your anonymous identity — so your real phone number is never exposed to anyone.',
        tip: 'Your Virtual Number looks like a real phone number but belongs only to Boofer.',
      ),
      _ArticleSection(
        heading: 'Setting Up Your Profile',
        body:
            'After sign-up you can personalise your profile with a display name, emoji avatar, bio, and links (Link Tree). Everything is optional — you control what others see.',
        steps: [
          _StepItem('1. Open Profile tab', 'Tap "You" in the bottom nav bar'),
          _StepItem('2. Tap Edit', 'Tap the pencil icon near your name'),
          _StepItem('3. Choose avatar', 'Pick from 100+ emoji avatars'),
          _StepItem('4. Add a bio', 'Write a short description about yourself'),
          _StepItem('5. Save', 'Changes are saved instantly'),
        ],
      ),
      _ArticleSection(
        heading: 'Three Main Tabs',
        body:
            'The bottom bar has three tabs: Home (discover people), Chats (your conversations), and You (your profile). The top app bar shows the Boofer logo, and on the Chats tab you\'ll find a Learn button and More options.',
      ),
    ],
  ),

  // 2 ─ Chats & Messaging
  _WikiArticle(
    id: 'chats-messaging',
    emoji: '💬',
    title: 'Chats & Messaging',
    subtitle: 'Send messages, media & more',
    color: Color(0xFF10B981),
    sections: [
      _ArticleSection(
        heading: 'Starting a Chat',
        body:
            'Navigate to the Chats tab. If you already have friends, tap any name to open the conversation. To start a new chat, find a user on the Home tab or search for them by username / virtual number.',
        tip: 'Long-press a chat tile for quick options like pin, mute, or archive.',
      ),
      _ArticleSection(
        heading: 'End-to-End Encryption',
        body:
            'Every message in Boofer is encrypted using the Signal Protocol before it leaves your device. Even Boofer cannot read your messages — only you and your recipient can.',
      ),
      _ArticleSection(
        heading: 'Sending Media',
        body:
            'Tap the attachment icon inside a chat to send images, videos, or files. You can also edit photos before sending using the built-in media editor.',
        steps: [
          _StepItem('Attachment 📎', 'Tap to open the media picker'),
          _StepItem('Emoji 😊', 'Tap the emoji button inside the text field'),
          _StepItem('Send ➤', 'Tap the send button outside the input box'),
        ],
      ),
      _ArticleSection(
        heading: 'Message Status Icons',
        body:
            'Below sent messages you\'ll see small status ticks:\n• ⏱ Pending — being delivered\n• ✓ Sent — reached our server\n• ✓✓ Delivered — reached their device\n• ✓✓ (blue) Read — they opened it\n• ⚠ Failed — tap to retry',
      ),
      _ArticleSection(
        heading: 'Pinning & Archiving',
        body:
            'Long-press a chat to pin it to the top of your list or move it to the Archived section. You can access archived chats via Settings → Chat → Archived Chats or through the "..." menu in the Chats top bar.',
        tip: 'In Settings → Archive Settings you can control where the archive button appears.',
      ),
    ],
  ),

  // 3 ─ Discover & Friends
  _WikiArticle(
    id: 'discover-friends',
    emoji: '🔍',
    title: 'Discover & Friends',
    subtitle: 'Find and connect with people',
    color: Color(0xFFF59E0B),
    sections: [
      _ArticleSection(
        heading: 'The Home Tab',
        body:
            'The Home tab shows discoverable users. You can switch between a list and a compact grid view using the grid toggle icon in the top-right corner of the app bar.',
        tip: 'Your grid/list preference is saved automatically across sessions.',
      ),
      _ArticleSection(
        heading: 'Following & Friends',
        body:
            'Boofer uses a two-step social graph: you can follow anyone publicly, but to chat you both need to be friends (mutual connection). Tap "Follow" on a user\'s profile to start, then wait for them to accept.',
      ),
      _ArticleSection(
        heading: 'Managing Friends',
        body:
            'Go to Home → "Manage friends" button (top right) to see pending requests, remove friends, or block users.',
        steps: [
          _StepItem('Pending In', 'Requests others sent you'),
          _StepItem('Pending Out', 'Requests you sent — awaiting approval'),
          _StepItem('Remove', 'Unfriend a current contact'),
          _StepItem('Block', 'Prevent someone from contacting you'),
        ],
      ),
      _ArticleSection(
        heading: 'User Search',
        body:
            'Use the search bar in the Chats tab or the global user search (accessible from "Explore Users" on an empty chat list) to find users by handle, name, or virtual number.',
      ),
      _ArticleSection(
        heading: 'QR Codes',
        body:
            'Share your profile as a QR code (Profile → Share Profile → QR Code) or scan someone else\'s code from Settings → QR Scanner. Fastest way to add friends in person!',
      ),
    ],
  ),

  // 4 ─ Privacy & Security
  _WikiArticle(
    id: 'privacy-security',
    emoji: '🔒',
    title: 'Privacy & Security',
    subtitle: 'How Boofer keeps you safe',
    color: Color(0xFFEF4444),
    sections: [
      _ArticleSection(
        heading: 'Virtual Identity',
        body:
            'Your Virtual Number is permanently assigned to your account. It acts like a phone number but never reveals your real number. Share it with friends instead of your personal contact.',
        tip: 'Go to your Profile to copy or share your Virtual Number at any time.',
      ),
      _ArticleSection(
        heading: 'Signal Protocol E2EE',
        body:
            'Boofer uses the same encryption protocol as Signal. Keys are generated on your device and never uploaded to our servers, making interception practically impossible.',
      ),
      _ArticleSection(
        heading: 'Privacy Controls',
        body:
            'Via Settings → Privacy you can control:\n• Who sees your Last Seen status\n• Who sees your Read Receipts\n• Who can view your Profile info\n• Profile picture visibility',
      ),
      _ArticleSection(
        heading: 'Blocked Users',
        body:
            'Block anyone from Settings → Blocked or by long-pressing a chat. Blocked users cannot message you, see your profile updates, or find your virtual number.',
      ),
      _ArticleSection(
        heading: 'Report & Moderation',
        body:
            'If you experience harassment, use Settings → Report Bug (or long-press a message) to report the issue directly to our moderation team.',
        tip: 'Your report is anonymous. We take all reports seriously.',
      ),
    ],
  ),

  // 5 ─ Profile & Identity
  _WikiArticle(
    id: 'profile-identity',
    emoji: '👤',
    title: 'Profile & Identity',
    subtitle: 'Customize how others see you',
    color: Color(0xFF8B5CF6),
    sections: [
      _ArticleSection(
        heading: 'Display Name & Handle',
        body:
            'Your handle (@username) is unique across Boofer and cannot be changed after sign-up. Your display name, however, can be updated anytime from the Profile edit screen.',
      ),
      _ArticleSection(
        heading: 'Avatar & Photo',
        body:
            'Choose an emoji avatar from 100+ options, or upload a real profile photo. You can have both — the emoji shows as a fallback if your photo fails to load.',
        steps: [
          _StepItem('Emoji Avatar', '100+ emoji options organized by category'),
          _StepItem('Profile Photo', 'Upload from your camera roll'),
          _StepItem('Company Badge', 'Verified businesses get a special badge'),
          _StepItem('Verified ✓', 'Blue checkmark for authenticated accounts'),
        ],
      ),
      _ArticleSection(
        heading: 'Bio & Link Tree',
        body:
            'Add a short bio and up to several links to your profile (e.g. Instagram, YouTube, personal website). Visitors can tap a link directly from your profile page.',
        tip: 'Link Tree links open in an in-app browser for a smooth experience.',
      ),
      _ArticleSection(
        heading: 'Multiple Accounts',
        body:
            'Boofer supports multiple identities. Long-press the "You" tab in the bottom nav to open the Identity Switcher. Switch accounts without signing out — each account maintains its own chat history.',
        steps: [
          _StepItem('Long-press "You" tab', 'Opens Identity Switcher sheet'),
          _StepItem('Tap an account', 'Instantly switches active identity'),
          _StepItem('ACTIVE badge', 'Shows which account is currently in use'),
        ],
      ),
      _ArticleSection(
        heading: 'Share Your Profile',
        body:
            'From the Profile screen tap "Share Profile" to send a link, display your QR code, or copy your virtual number. Great for networking!',
      ),
    ],
  ),

  // 6 ─ Customization
  _WikiArticle(
    id: 'customization',
    emoji: '🎨',
    title: 'Customization',
    subtitle: 'Make Boofer feel like yours',
    color: Color(0xFFEC4899),
    sections: [
      _ArticleSection(
        heading: 'Dark Mode & Themes',
        body:
            'Toggle dark mode from the "..." More Options menu on the app bar, or go to Settings → Customization to pick Light, Dark, or follow System. Multiple accent colour presets are available.',
        tip: 'Tap "..." (More Options) → toggle switch for an instant theme flip.',
      ),
      _ArticleSection(
        heading: 'Customization Settings',
        body:
            'Settings → Customization lets you control:\n• Accent colour\n• App text size\n• Icon style\n• Font style\n• Corner radius (bubble roundness)',
      ),
      _ArticleSection(
        heading: 'Chat Appearance',
        body:
            'Settings → Chat Appearance lets you personalise chat bubbles:\n• Bubble shape & colour\n• Wallpaper (solid colour, gradient, or image)\n• Chat font size\n• Navigation bar style (6 styles available)',
        steps: [
          _StepItem('Simple', 'Classic Android bottom bar'),
          _StepItem('Modern', 'Animated pill that expands on selection'),
          _StepItem('iOS', 'Circular highlight style'),
          _StepItem('Bubble', 'Rounded bubble beneath icon'),
          _StepItem('Liquid', 'Floating icon with a dot indicator'),
          _StepItem('Gen Z', 'Gradient rectangle highlight'),
        ],
      ),
      _ArticleSection(
        heading: 'Language',
        body:
            'Settings → Language. Currently supported: English, Spanish, French, German, and Italian. More languages coming soon.',
      ),
    ],
  ),

  // 7 ─ Notifications
  _WikiArticle(
    id: 'notifications',
    emoji: '🔔',
    title: 'Notifications',
    subtitle: 'Stay informed, on your terms',
    color: Color(0xFFF97316),
    sections: [
      _ArticleSection(
        heading: 'Enabling Notifications',
        body:
            'On first launch, Boofer asks for notification permission. If you declined, go to Settings → Notifications → toggle Message Notifications to turn it back on.',
      ),
      _ArticleSection(
        heading: 'Per-Chat Muting',
        body:
            'Long-press a chat tile to mute/unmute that specific conversation. Muted chats still receive messages and show an unread badge with a mute 🔇 icon — you just won\'t hear a sound.',
        tip: 'A muted chat\'s unread badge appears grey instead of your accent colour.',
      ),
      _ArticleSection(
        heading: 'Notification Settings Screen',
        body:
            'Settings → Notifications gives you fine-grained control:',
        steps: [
          _StepItem('Message Notifications', 'Toggle all message alerts'),
          _StepItem('Sound', 'Choose notification sound'),
          _StepItem('Vibration', 'Enable/disable haptics'),
          _StepItem('Previews', 'Show or hide message preview in notifications'),
        ],
      ),
    ],
  ),

  // 8 ─ Settings & Storage
  _WikiArticle(
    id: 'settings-storage',
    emoji: '⚙️',
    title: 'Settings & Storage',
    subtitle: 'Configure and manage your data',
    color: Color(0xFF0EA5E9),
    sections: [
      _ArticleSection(
        heading: 'Settings Overview',
        body:
            'Open Settings from the "..." More Options menu on the app bar. Settings are organized into clear sections:\n\nPersonalization → Customization, Chat Appearance, Language\nPrivacy & Security → Privacy, Blocked users\nNotifications → Sound, vibration\nChat → Archived, Archive settings\nData & Storage → Network usage, Clear cache\nApp Updates → Version updates, Changelogs\nAbout → Help, Feedback, Bug report, Legal',
        tip: 'Use the search bar at the top of Settings to find anything instantly.',
      ),
      _ArticleSection(
        heading: 'Clear Cache',
        body:
            'If Boofer feels sluggish, try Settings → Data & Storage → Clear Cache. This removes temporary files but keeps your messages safe.',
      ),
      _ArticleSection(
        heading: 'Network Usage',
        body:
            'Settings → Network Usage shows how much data the app has consumed for messages, media, and background tasks — helpful for monitoring mobile data.',
      ),
      _ArticleSection(
        heading: 'App Updates (Shorebird)',
        body:
            'Boofer uses Shorebird for instant over-the-air patches. When an update is ready, a banner appears at the top of the Chats screen. Tap "RESTART" to apply it instantly without a Play Store update.',
        tip: 'For full version releases, check Settings → Updates.',
      ),
    ],
  ),

  // 9 ─ Support & Help
  _WikiArticle(
    id: 'support-help',
    emoji: '🛣️',
    title: 'Support & Help',
    subtitle: 'We\'re here for you',
    color: Color(0xFF14B8A6),
    sections: [
      _ArticleSection(
        heading: 'Boofer Support Chat',
        body:
            'The fastest way to get help is through the in-app support chat. Tap "..." → Boofer to open a live thread with our support team.',
        tip: 'The Boofer support account has a 🛣️ emoji and a verified badge.',
      ),
      _ArticleSection(
        heading: 'Help Center',
        body:
            'Settings → Help Center contains FAQ articles and troubleshooting guides for the most common issues: connectivity, notifications, performance, and privacy.',
      ),
      _ArticleSection(
        heading: 'Send Feedback',
        body:
            'Love a feature? Wish something worked differently? Settings → Send Feedback lets you share detailed thoughts. Our product team reads every submission.',
      ),
      _ArticleSection(
        heading: 'Report a Bug',
        body:
            'Found something broken? Settings → Report Bug submits a structured report with device information automatically attached.',
        steps: [
          _StepItem('Category', 'Select the area of the app'),
          _StepItem('Description', 'Describe what happened'),
          _StepItem('Steps to reproduce', 'Help us replicate it'),
          _StepItem('Submit', 'Sent directly to our engineering team'),
        ],
      ),
      _ArticleSection(
        heading: 'Legal',
        body:
            'Settings → Privacy Policy and Settings → Terms of Service contain the full legal documents. We keep them human-readable — no legalese maze.',
      ),
    ],
  ),

  // 10 ─ About Boofer
  _WikiArticle(
    id: 'about',
    emoji: '🇮🇳',
    title: 'About Boofer',
    subtitle: 'Proudly Indian, globally private',
    color: Color(0xFFFF6B35),
    sections: [
      _ArticleSection(
        heading: 'Our Mission',
        body:
            'Boofer was born in India with a single goal: build a messaging platform that puts privacy first without sacrificing the features users love. We believe communication should be safe, free, and expressive.',
      ),
      _ArticleSection(
        heading: 'By Shaadow',
        body:
            'Boofer is developed and maintained by Shaadow — an indie studio also behind FavTunes (music playlists app). We\'re a small team that ships fast and listens closely to users.',
        tip: 'Check out FavTunes in Settings → By Shaadow if you love music!',
      ),
      _ArticleSection(
        heading: 'Changelogs & Versions',
        body:
            'Settings → Latest Highlights shows what changed in the most recent update. Settings → Updates lets you manually check for and apply new versions.',
      ),
      _ArticleSection(
        heading: 'Open Source & Transparency',
        body:
            'Our firestore security rules and key architectural decisions are documented and available for inspection. We believe transparency builds trust.',
      ),
    ],
  ),
];

// ─────────────────────────────────────────────
// MAIN LEARN SCREEN
// ─────────────────────────────────────────────

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  List<_WikiArticle> get _filtered {
    if (_query.isEmpty) return _wikiArticles;
    final q = _query.toLowerCase();
    return _wikiArticles.where((a) {
      if (a.title.toLowerCase().contains(q)) return true;
      if (a.subtitle.toLowerCase().contains(q)) return true;
      for (final s in a.sections) {
        if (s.heading.toLowerCase().contains(q)) return true;
        if (s.body.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Large App Bar ──
          SliverAppBar.large(
            backgroundColor: cs.surface,
            scrolledUnderElevation: 0,
            title: const Text(
              'Learn Boofer',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
            ),
          ),

          // ── Hero Banner (shown when no search) ──
          if (_query.isEmpty)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _HeroBanner(theme: theme),
              ),
            ),

          // ── Article Grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: _filtered.isEmpty
                ? SliverToBoxAdapter(child: _EmptyState(query: _query))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final article = _filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ArticleCard(
                            article: article,
                            searchQuery: _query,
                            onTap: () => _openArticle(context, article),
                          ),
                        );
                      },
                      childCount: _filtered.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openArticle(BuildContext context, _WikiArticle article) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArticleDetailScreen(
          article: article,
          allArticles: _wikiArticles,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final ThemeData theme;
  const _HeroBanner({required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BOOFER WIKI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Everything you need to know',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_wikiArticles.length} articles · always up to date',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('📖', style: TextStyle(fontSize: 52)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: cs.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search features, routes, tips…',
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: cs.onSurfaceVariant, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ARTICLE CARD
// ─────────────────────────────────────────────

class _ArticleCard extends StatefulWidget {
  final _WikiArticle article;
  final String searchQuery;
  final VoidCallback onTap;
  const _ArticleCard({
    required this.article,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final article = widget.article;
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => _hoverCtrl.forward(),
        onTapUp: (_) {
          _hoverCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _hoverCtrl.reverse(),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerLow.withValues(alpha: 0.7)
                : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: article.color.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: article.color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji Badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: article.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    article.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      article.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(
                          label: '${article.sections.length} sections',
                          color: article.color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Arrow
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: article.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: article.color,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try different keywords',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ARTICLE DETAIL SCREEN
// ─────────────────────────────────────────────

class _ArticleDetailScreen extends StatefulWidget {
  final _WikiArticle article;
  final List<_WikiArticle> allArticles;

  const _ArticleDetailScreen({
    required this.article,
    required this.allArticles,
  });

  @override
  State<_ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<_ArticleDetailScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late _WikiArticle _current;
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _swapCtrl;
  late Animation<double> _fadeAnim;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allArticles.indexOf(widget.article);
    if (_currentIndex < 0) _currentIndex = 0;
    _current = widget.allArticles[_currentIndex];
    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _swapCtrl, curve: Curves.easeInOut);
    _swapCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _swapCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateTo(int newIndex) async {
    if (_isAnimating) return;
    _isAnimating = true;
    await _swapCtrl.reverse();
    if (!mounted) return;
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    setState(() {
      _currentIndex = newIndex;
      _current = widget.allArticles[newIndex];
    });
    await _swapCtrl.forward();
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < widget.allArticles.length - 1;
    final prev = hasPrev ? widget.allArticles[_currentIndex - 1] : null;
    final next = hasNext ? widget.allArticles[_currentIndex + 1] : null;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // Large collapsing header
            SliverAppBar.large(
              backgroundColor: cs.surface,
              scrolledUnderElevation: 0,
              expandedHeight: 160,
              flexibleSpace: FlexibleSpaceBar(
                background: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              _current.color.withValues(alpha: 0.3),
                              _current.color.withValues(alpha: 0.05),
                            ]
                          : [
                              _current.color.withValues(alpha: 0.12),
                              _current.color.withValues(alpha: 0.02),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24, bottom: 16),
                      child: Text(
                        _current.emoji,
                        style: const TextStyle(fontSize: 72),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  _current.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),

            // Subtitle chip + position indicator
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _current.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _current.subtitle,
                        style: TextStyle(
                          color: _current.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentIndex + 1} / ${widget.allArticles.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sections
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _SectionCard(
                    section: _current.sections[i],
                    accentColor: _current.color,
                    index: i,
                  ),
                  childCount: _current.sections.length,
                ),
              ),
            ),

            // Bottom spacer so nav bar doesn't cover content
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      // ── Sticky Prev / Next navigation bar ──
      bottomNavigationBar: _NavBar(
        prev: prev,
        next: next,
        accentColor: _current.color,
        onPrev: hasPrev ? () => _navigateTo(_currentIndex - 1) : null,
        onNext: hasNext ? () => _navigateTo(_currentIndex + 1) : null,
        currentIndex: _currentIndex,
        total: widget.allArticles.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PREV / NEXT NAV BAR
// ─────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final _WikiArticle? prev;
  final _WikiArticle? next;
  final Color accentColor;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final int currentIndex;
  final int total;

  const _NavBar({
    required this.prev,
    required this.next,
    required this.accentColor,
    required this.onPrev,
    required this.onNext,
    required this.currentIndex,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPad),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Prev button
          Expanded(
            child: _NavButton(
              label: prev?.title ?? '',
              emoji: prev?.emoji ?? '',
              direction: _NavDirection.prev,
              color: prev?.color ?? accentColor,
              enabled: onPrev != null,
              onTap: () {
                HapticFeedback.selectionClick();
                onPrev?.call();
              },
            ),
          ),

          // Progress dots
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _ProgressDots(
              current: currentIndex,
              total: total,
              activeColor: accentColor,
            ),
          ),

          // Next button
          Expanded(
            child: _NavButton(
              label: next?.title ?? '',
              emoji: next?.emoji ?? '',
              direction: _NavDirection.next,
              color: next?.color ?? accentColor,
              enabled: onNext != null,
              onTap: () {
                HapticFeedback.selectionClick();
                onNext?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _NavDirection { prev, next }

class _NavButton extends StatefulWidget {
  final String label;
  final String emoji;
  final _NavDirection direction;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.emoji,
    required this.direction,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPrev = widget.direction == _NavDirection.prev;

    if (!widget.enabled) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            isPrev ? '← Start' : 'End →',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.22),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                isPrev ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: isPrev
                ? [
                    Icon(Icons.chevron_left_rounded,
                        color: widget.color, size: 20),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'PREV',
                            style: TextStyle(
                              color: widget.color.withValues(alpha: 0.65),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${widget.emoji} ${widget.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'NEXT',
                            style: TextStyle(
                              color: widget.color.withValues(alpha: 0.65),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${widget.emoji} ${widget.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: widget.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: widget.color, size: 20),
                  ],
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;
  final Color activeColor;
  const _ProgressDots({
    required this.current,
    required this.total,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const maxDots = 5;
    const half = maxDots ~/ 2;
    final start = (current - half).clamp(0, (total - maxDots).clamp(0, total));
    final end = (start + maxDots).clamp(0, total);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(end - start, (i) {
            final idx = start + i;
            final isActive = idx == current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: isActive ? 14 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor
                    : cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  final _ArticleSection section;
  final Color accentColor;
  final int index;
  const _SectionCard({
    required this.section,
    required this.accentColor,
    required this.index,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = widget.section;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? cs.surfaceContainerLow.withValues(alpha: 0.7)
              : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: _toggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.index + 1}',
                          style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.heading,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Collapsible Body
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildBody(context, s),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, _ArticleSection s) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
          const SizedBox(height: 12),

          // Body text
          Text(
            s.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),

          // Steps
          if (s.steps != null) ...[
            const SizedBox(height: 14),
            ...s.steps!.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step.label,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          step.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.75),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Tip
          if (s.tip != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.tip!,
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
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
}
