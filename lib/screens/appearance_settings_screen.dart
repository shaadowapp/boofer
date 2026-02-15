import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';

import '../providers/appearance_provider.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  // _brandColors removed as it is now in CustomizationSettingsScreen

  final List<Map<String, dynamic>> _wallpapers = [
    {'id': 'none', 'name': 'None', 'type': 'none'},
    // Solid colors
    {
      'id': 'solid1',
      'name': 'Soft White',
      'type': 'solid',
      'color': const Color(0xFFF5F5F5),
    },
    {
      'id': 'solid2',
      'name': 'Soft Green',
      'type': 'solid',
      'color': const Color(0xFFE8F5E9),
    },
    {
      'id': 'solid3',
      'name': 'Soft Blue',
      'type': 'solid',
      'color': const Color(0xFFE3F2FD),
    },
    {
      'id': 'solid4',
      'name': 'Soft Orange',
      'type': 'solid',
      'color': const Color(0xFFFFF3E0),
    },
    {
      'id': 'solid5',
      'name': 'Soft Purple',
      'type': 'solid',
      'color': const Color(0xFFF3E5F5),
    },
    {
      'id': 'solid6',
      'name': 'Soft Pink',
      'type': 'solid',
      'color': const Color(0xFFFCE4EC),
    },
    {
      'id': 'solid7',
      'name': 'Soft Yellow',
      'type': 'solid',
      'color': const Color(0xFFFFFDE7),
    },
    {
      'id': 'solid8',
      'name': 'Soft Teal',
      'type': 'solid',
      'color': const Color(0xFFE0F2F1),
    },
    {
      'id': 'solid9',
      'name': 'Soft Indigo',
      'type': 'solid',
      'color': const Color(0xFFE8EAF6),
    },
    {
      'id': 'solid10',
      'name': 'Soft Amber',
      'type': 'solid',
      'color': const Color(0xFFFFF8E1),
    },
    // Gradients
    {'id': 'gradient1', 'name': 'Warm Yellow', 'type': 'gradient'},
    {'id': 'gradient2', 'name': 'Soft Pink', 'type': 'gradient'},
    {'id': 'gradient3', 'name': 'Peach', 'type': 'gradient'},
    {'id': 'gradient4', 'name': 'Sky Blue', 'type': 'gradient'},
    {'id': 'gradient5', 'name': 'Mint Green', 'type': 'gradient'},
    {'id': 'gradient6', 'name': 'Lavender', 'type': 'gradient'},
    {'id': 'gradient7', 'name': 'Coral Sunset', 'type': 'gradient'},
    {'id': 'gradient8', 'name': 'Purple Dream', 'type': 'gradient'},
    {'id': 'gradient9', 'name': 'Fire', 'type': 'gradient'},
    {'id': 'gradient10', 'name': 'Ocean Blue', 'type': 'gradient'},
    {'id': 'gradient11', 'name': 'Sunset', 'type': 'gradient'},
    {'id': 'gradient12', 'name': 'Cotton Candy', 'type': 'gradient'},
    {'id': 'gradient13', 'name': 'Forest', 'type': 'gradient'},
    {'id': 'gradient14', 'name': 'Rose Gold', 'type': 'gradient'},
    {'id': 'gradient15', 'name': 'Northern Lights', 'type': 'gradient'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // themeProvider not needed here anymore for this screen
    final appearanceProvider = Provider.of<AppearanceProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Chat Appearance'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Bubble Customization Preview
                _buildSectionContainer(
                  context,
                  title: 'Chat Appearance',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.blue,
                  children: [
                    Text(
                      'Customize your chat experience',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bubble Shape Selection
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildShapeOption(
                            context,
                            appearanceProvider,
                            ChatBubbleShape.round,
                            Icons.circle_outlined,
                            'Round',
                          ),
                          const SizedBox(width: 12),
                          _buildShapeOption(
                            context,
                            appearanceProvider,
                            ChatBubbleShape.curve,
                            Icons.bubble_chart_outlined,
                            'Curve',
                          ),
                          const SizedBox(width: 12),
                          _buildShapeOption(
                            context,
                            appearanceProvider,
                            ChatBubbleShape.square,
                            Icons.crop_square_rounded,
                            'Square',
                          ),
                          const SizedBox(width: 12),
                          _buildShapeOption(
                            context,
                            appearanceProvider,
                            ChatBubbleShape.capsule,
                            Icons.stadium_outlined,
                            'Capsule',
                          ),
                          const SizedBox(width: 12),
                          _buildShapeOption(
                            context,
                            appearanceProvider,
                            ChatBubbleShape.leaf,
                            Icons.eco_outlined,
                            'Leaf',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Typography Slider
                    Row(
                      children: [
                        const Icon(Icons.text_format, size: 18),
                        Expanded(
                          child: Slider(
                            value: appearanceProvider.bubbleFontSize,
                            min: 12,
                            max: 24,
                            divisions: 6,
                            onChanged: (v) =>
                                appearanceProvider.setBubbleFontSize(v),
                          ),
                        ),
                        const Icon(Icons.text_format, size: 26),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Live Preview
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(50),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          _buildPreviewBubble(
                            context,
                            appearanceProvider,
                            'Hey! How does this look?',
                            true,
                          ),
                          const SizedBox(height: 12),
                          _buildPreviewBubble(
                            context,
                            appearanceProvider,
                            'It looks absolutely stunning.',
                            false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Chat Wallpaper Section
                _buildSectionContainer(
                  context,
                  title: 'Chat Wallpaper',
                  icon: Icons.wallpaper_rounded,
                  color: Colors.deepPurple,
                  children: [
                    Text(
                      'Choose a background for your chats',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // None option
                    _buildWallpaperOption(
                      context,
                      'none',
                      'Default',
                      appearanceProvider,
                      theme,
                      height: 60,
                      width: double.infinity,
                    ),

                    const SizedBox(height: 16),

                    // Solid Colors Section
                    _buildWallpaperSubSection(
                      context,
                      title: 'Solid Colors',
                      wallpapers: _wallpapers
                          .where((w) => w['type'] == 'solid')
                          .toList(),
                      appearanceProvider: appearanceProvider,
                      theme: theme,
                    ),

                    // Gradients Section
                    _buildWallpaperSubSection(
                      context,
                      title: 'Gradients',
                      wallpapers: _wallpapers
                          .where((w) => w['type'] == 'gradient')
                          .toList(),
                      appearanceProvider: appearanceProvider,
                      theme: theme,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildShapeOption(
    BuildContext context,
    AppearanceProvider provider,
    ChatBubbleShape shape,
    IconData icon,
    String label,
  ) {
    final theme = Theme.of(context);
    final isSelected = provider.chatBubbleShape == shape;

    return GestureDetector(
      onTap: () => provider.setChatBubbleShape(shape),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Build wallpaper subsection with horizontal scroll
  Widget _buildWallpaperSubSection(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> wallpapers,
    required AppearanceProvider appearanceProvider,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: wallpapers.length,
            itemBuilder: (context, index) {
              final wallpaper = wallpapers[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < wallpapers.length - 1 ? 12 : 0,
                ),
                child: _buildWallpaperOption(
                  context,
                  wallpaper['id'],
                  wallpaper['name'],
                  appearanceProvider,
                  theme,
                  width: 90,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Build individual wallpaper option
  Widget _buildWallpaperOption(
    BuildContext context,
    String id,
    String name,
    AppearanceProvider appearanceProvider,
    ThemeData theme, {
    double? width,
    double? height,
  }) {
    final isSelected = appearanceProvider.selectedWallpaper == id;

    return GestureDetector(
      onTap: () => appearanceProvider.setWallpaper(id),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.1),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (id != 'none')
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  14,
                ), // slightly less than container for border
                child: _buildWallpaperPreview(id),
              ),
            if (id == 'none')
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.do_not_disturb_alt_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            if (id != 'none')
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    backgroundBlendMode: BlendMode.darken,
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperPreview(String wallpaperId) {
    final wallpaper = _wallpapers.firstWhere((w) => w['id'] == wallpaperId);
    final type = wallpaper['type'] as String;

    if (type == 'solid') {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: wallpaper['color'] as Color),
      );
    }

    // Gradient
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(wallpaperId),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String wallpaperId) {
    switch (wallpaperId) {
      case 'gradient1':
        return [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)];
      case 'gradient2':
        return [const Color(0xFFFCE7F3), const Color(0xFFFBCFE8)];
      case 'gradient3':
        return [const Color(0xFFFFE5B4), const Color(0xFFFFD4A3)];
      case 'gradient4':
        return [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)];
      case 'gradient5':
        return [const Color(0xFFDCFCE7), const Color(0xFFBBF7D0)];
      case 'gradient6':
        return [const Color(0xFFE9D5FF), const Color(0xFFD8B4FE)];
      case 'gradient7':
        return [const Color(0xFFFF9A9E), const Color(0xFFFAD0C4)];
      case 'gradient8':
        return [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)];
      case 'gradient9':
        return [const Color(0xFFFAD961), const Color(0xFFF76B1C)];
      case 'gradient10':
        return [const Color(0xFF89F7FE), const Color(0xFF66A6FF)];
      case 'gradient11':
        return [const Color(0xFFFFD89B), const Color(0xFF19547B)];
      case 'gradient12':
        return [const Color(0xFFFF6E7F), const Color(0xFFBFE9FF)];
      case 'gradient13':
        return [const Color(0xFF134E5E), const Color(0xFF71B280)];
      case 'gradient14':
        return [const Color(0xFFEEA4CE), const Color(0xFFC58BF2)];
      case 'gradient15':
        return [const Color(0xFF00C9FF), const Color(0xFF92FE9D)];
      default:
        return [Colors.grey.shade200, Colors.grey.shade300];
    }
  }

  Widget _buildPreviewBubble(
    BuildContext context,
    AppearanceProvider appearance,
    String text,
    bool isOwn,
  ) {
    return Row(
      mainAxisAlignment: isOwn
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [_buildBubbleContent(context, appearance, text, isOwn)],
    );
  }

  Widget _buildBubbleContent(
    BuildContext context,
    AppearanceProvider appearance,
    String text,
    bool isOwn,
  ) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        minWidth: 60,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOwn
            ? appearance.accentColor
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: _getPreviewRadius(isOwn, appearance.chatBubbleShape),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: appearance.bubbleFontSize,
          color: isOwn ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  BorderRadius _getPreviewRadius(bool isOwn, ChatBubbleShape shape) {
    switch (shape) {
      case ChatBubbleShape.round: // Pill style (Uniform)
        return BorderRadius.circular(32);
      case ChatBubbleShape.curve: // Round with tail
        return BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isOwn
              ? const Radius.circular(20)
              : const Radius.circular(6),
          bottomRight: isOwn
              ? const Radius.circular(6)
              : const Radius.circular(20),
        );
      case ChatBubbleShape.square: // Rectangular minimal rounded
        return BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: isOwn
              ? const Radius.circular(8)
              : const Radius.circular(2),
          bottomRight: isOwn
              ? const Radius.circular(2)
              : const Radius.circular(8),
        );
      case ChatBubbleShape.capsule: // Rounded with rounded tail
        return BorderRadius.only(
          topLeft: const Radius.circular(28),
          topRight: const Radius.circular(28),
          bottomLeft: isOwn
              ? const Radius.circular(28)
              : const Radius.circular(12),
          bottomRight: isOwn
              ? const Radius.circular(12)
              : const Radius.circular(28),
        );
      case ChatBubbleShape.leaf:
        return BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: isOwn
              ? const Radius.circular(4)
              : const Radius.circular(24),
          bottomLeft: isOwn
              ? const Radius.circular(24)
              : const Radius.circular(4),
          bottomRight: const Radius.circular(24),
        );
    }
  }
}
