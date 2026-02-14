import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/svg_icons.dart';
import '../providers/theme_provider.dart';
import '../providers/appearance_provider.dart';

class CustomizationSettingsScreen extends StatefulWidget {
  const CustomizationSettingsScreen({super.key});

  @override
  State<CustomizationSettingsScreen> createState() =>
      _CustomizationSettingsScreenState();
}

class _CustomizationSettingsScreenState
    extends State<CustomizationSettingsScreen> {
  final List<Color> _brandColors = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Green
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Orange
    const Color(0xFF8B5CF6), // Purple
  ];

  final List<Map<String, dynamic>> _accentGradients = [
    {
      'id': 'sunset',
      'colors': [const Color(0xFFFFB74D), const Color(0xFFEC4899)],
    },
    {
      'id': 'ocean',
      'colors': [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
    },
    {
      'id': 'lush',
      'colors': [const Color(0xFF10B981), const Color(0xFF06B6D4)],
    },
    {
      'id': 'royal',
      'colors': [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
    },
    {
      'id': 'fire',
      'colors': [const Color(0xFFEF4444), const Color(0xFFF59E0B)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Customization'),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Theme Section
                _buildSectionContainer(
                  context,
                  title: 'Theme',
                  icon: Icons.brightness_6_outlined,
                  color: Colors.indigo,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          themeProvider.isDarkMode
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      title: const Text(
                        'Theme Mode',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(themeProvider.themeModeString),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      onTap: () => _showThemeDialog(context, themeProvider),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Brand Color Section
                _buildSectionContainer(
                  context,
                  title: 'Accent Color',
                  icon: Icons.palette_outlined,
                  color: Colors.pink,
                  children: [
                    Text(
                      'Choose your accent color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _brandColors.map((color) {
                        final isSelected =
                            !appearanceProvider.useGradientAccent &&
                            appearanceProvider.accentColor.value == color.value;
                        return GestureDetector(
                          onTap: () => appearanceProvider.setAccentColor(color),
                          child: _buildColorOption(context, color, isSelected),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _accentGradients.map((gradient) {
                        final id = gradient['id'] as String;
                        final colors = gradient['colors'] as List<Color>;
                        final isSelected =
                            appearanceProvider.useGradientAccent &&
                            appearanceProvider.selectedGradientId == id;
                        return GestureDetector(
                          onTap: () => appearanceProvider.setAccentGradient(id),
                          child: _buildGradientOption(
                            context,
                            colors,
                            isSelected,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Navigation Bar Style Section
                _buildSectionContainer(
                  context,
                  title: 'Navigation Bar Style',
                  icon: Icons.view_column_rounded,
                  color: Colors.cyan,
                  children: [
                    Text(
                      'Choose your navigation bar style',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preview Area
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        child: _buildNavBarPreview(
                          context,
                          appearanceProvider.navBarStyle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.8,
                      children: [
                        _buildNavBarOption(
                          context,
                          title: 'Classic', // Simple
                          style: NavBarStyle.simple,
                          isSelected:
                              appearanceProvider.navBarStyle ==
                              NavBarStyle.simple,
                          onTap: () => appearanceProvider.setNavBarStyle(
                            NavBarStyle.simple,
                          ),
                        ),
                        _buildNavBarOption(
                          context,
                          title: 'Modern',
                          style: NavBarStyle.modern,
                          isSelected:
                              appearanceProvider.navBarStyle ==
                              NavBarStyle.modern,
                          onTap: () => appearanceProvider.setNavBarStyle(
                            NavBarStyle.modern,
                          ),
                        ),
                        _buildNavBarOption(
                          context,
                          title: 'Glass', // iOS Style renamed
                          style: NavBarStyle.ios,
                          isSelected:
                              appearanceProvider.navBarStyle == NavBarStyle.ios,
                          onTap: () => appearanceProvider.setNavBarStyle(
                            NavBarStyle.ios,
                          ),
                        ),
                        _buildNavBarOption(
                          context,
                          title: 'Playful',
                          style: NavBarStyle.bubble,
                          isSelected:
                              appearanceProvider.navBarStyle ==
                              NavBarStyle.bubble,
                          onTap: () => appearanceProvider.setNavBarStyle(
                            NavBarStyle.bubble,
                          ),
                        ),
                        _buildNavBarOption(
                          context,
                          title: 'Liquid',
                          style: NavBarStyle.liquid,
                          isSelected:
                              appearanceProvider.navBarStyle ==
                              NavBarStyle.liquid,
                          onTap: () => appearanceProvider.setNavBarStyle(
                            NavBarStyle.liquid,
                          ),
                        ),
                        _buildNavBarOption(
                          context,
                          title: 'GenZ',
                          style: NavBarStyle.genz,
                          isSelected:
                              appearanceProvider.navBarStyle ==
                              NavBarStyle.genz,
                          onTap: () => appearanceProvider.setNavBarStyle(
                            NavBarStyle.genz,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // App Text Size Section (Accessibility)
                _buildSectionContainer(
                  context,
                  title: 'App Text Size',
                  icon: Icons.format_size_rounded,
                  color: Colors.teal,
                  children: [
                    Text(
                      'Adjust text size for the app interface',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 6.0,
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 10.0,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 20.0,
                                    ),
                                  ),
                                  child: Slider(
                                    value: appearanceProvider.appFontSize,
                                    min: 14.0,
                                    max: 20.0,
                                    divisions: 3,
                                    label: _getFontSizeLabel(
                                      appearanceProvider.appFontSize,
                                    ),
                                    onChanged: (value) {
                                      appearanceProvider.setAppFontSize(value);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // App UI Preview
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.settings,
                                  size: appearanceProvider.appFontSize + 4,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Settings',
                                        style: TextStyle(
                                          fontSize:
                                              appearanceProvider.appFontSize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'General, Privacy, Security',
                                        style: TextStyle(
                                          fontSize:
                                              appearanceProvider.appFontSize -
                                              2, // Slightly smaller
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Preview: ${_getFontSizeLabel(appearanceProvider.appFontSize)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // UI Style Section (Corner Radius)
                _buildSectionContainer(
                  context,
                  title: 'UI Style',
                  icon: Icons.style_outlined,
                  color: Colors.deepPurple,
                  children: [
                    Text(
                      'Adjust ui corner radius',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.crop_square_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 6.0,
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 10.0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 20.0,
                                  ),
                                ),
                                child: Slider(
                                  value: appearanceProvider.cornerRadius,
                                  min: 4.0,
                                  max: 28.0,
                                  divisions: 6,
                                  label:
                                      '${appearanceProvider.cornerRadius.toInt()}',
                                  onChanged: (value) {
                                    appearanceProvider.setCornerRadius(value);
                                  },
                                ),
                              ),
                            ),
                            Icon(
                              Icons.circle_outlined,
                              size: 24,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Corner Radius Preview
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Container(
                              width: 80,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  appearanceProvider.cornerRadius,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Button',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(
                                  appearanceProvider.cornerRadius,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.favorite,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  String _getFontSizeLabel(double fontSize) {
    if (fontSize <= 14.0) return 'Small';
    if (fontSize <= 16.0) return 'Medium';
    if (fontSize <= 18.0) return 'Large';
    return 'Extra Large';
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppThemeMode>(
              title: const Text('Light'),
              value: AppThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('Dark'),
              value: AppThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(
              title: const Text('System Default'),
              value: AppThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarOption(
    BuildContext context, {
    required String title,
    required NavBarStyle style,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getNavBarIcon(style),
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? color : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNavBarIcon(NavBarStyle style) {
    switch (style) {
      case NavBarStyle.simple:
        return Icons.video_label;
      case NavBarStyle.modern:
        return Icons.dns_rounded;
      case NavBarStyle.ios:
        return Icons.blur_on_rounded;
      case NavBarStyle.bubble:
        return Icons.bubble_chart_rounded;
      case NavBarStyle.liquid:
        return Icons.water_drop_rounded;
      case NavBarStyle.genz:
        return Icons.auto_awesome_rounded;
    }
  }

  Widget _buildNavBarPreview(BuildContext context, NavBarStyle style) {
    switch (style) {
      case NavBarStyle.simple:
        return _buildSimplePreview(context);
      case NavBarStyle.modern:
        return _buildModernPreview(context);
      case NavBarStyle.ios:
        return _buildIOSPreview(context);
      case NavBarStyle.bubble:
        return _buildBubblePreview(context);
      case NavBarStyle.liquid:
        return _buildLiquidPreview(context);
      case NavBarStyle.genz:
        return _buildGenZPreview(context);
    }
  }

  Widget _buildSimplePreview(BuildContext context) {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (_) {},
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      elevation: 0,
      backgroundColor: Colors.transparent,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'You'),
        BottomNavigationBarItem(
          icon: SvgIcons.chat(filled: false, context: context),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: SvgIcons.call(filled: false, context: context),
          label: 'Calls',
        ),
      ],
    );
  }

  Widget _buildModernPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPreviewItem(context, 'You', true, NavBarStyle.modern),
          _buildPreviewItem(context, 'Chats', false, NavBarStyle.modern),
          _buildPreviewItem(context, 'Calls', false, NavBarStyle.modern),
        ],
      ),
    );
  }

  Widget _buildIOSPreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPreviewItem(context, 'You', true, NavBarStyle.ios),
                _buildPreviewItem(context, 'Chats', false, NavBarStyle.ios),
                _buildPreviewItem(context, 'Calls', false, NavBarStyle.ios),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubblePreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPreviewItem(context, 'You', true, NavBarStyle.bubble),
          _buildPreviewItem(context, 'Chats', false, NavBarStyle.bubble),
          _buildPreviewItem(context, 'Calls', false, NavBarStyle.bubble),
        ],
      ),
    );
  }

  Widget _buildLiquidPreview(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 3;
        return Container(
          height: 80,
          child: Stack(
            children: [
              // Simulated background pill like in actual UI
              Positioned(
                left: (itemWidth - 56) / 2, // Centered in first item (You)
                top: 12,
                width: 56,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPreviewItem(context, 'You', true, NavBarStyle.liquid),
                  _buildPreviewItem(
                    context,
                    'Chats',
                    false,
                    NavBarStyle.liquid,
                  ),
                  _buildPreviewItem(
                    context,
                    'Calls',
                    false,
                    NavBarStyle.liquid,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenZPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPreviewItem(context, 'You', true, NavBarStyle.genz),
          _buildPreviewItem(context, 'Chats', false, NavBarStyle.genz),
          _buildPreviewItem(context, 'Calls', false, NavBarStyle.genz),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(
    BuildContext context,
    String label,
    bool isSelected,
    NavBarStyle style,
  ) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    Widget icon;
    if (label == 'Chats') {
      icon = SvgIcons.chat(
        filled: isSelected,
        context: context,
        color:
            isSelected && style != NavBarStyle.ios && style != NavBarStyle.genz
            ? color
            : theme.colorScheme.onSurfaceVariant,
      );
      if (style == NavBarStyle.ios && isSelected) {
        icon = SvgIcons.chat(
          filled: true,
          context: context,
          color: Colors.white,
        );
      } else if (style == NavBarStyle.genz && isSelected) {
        icon = SvgIcons.chat(
          filled: true,
          context: context,
          color: Colors.white,
        );
      }
    } else if (label == 'Calls') {
      icon = SvgIcons.call(
        filled: isSelected,
        context: context,
        color:
            isSelected && style != NavBarStyle.ios && style != NavBarStyle.genz
            ? color
            : theme.colorScheme.onSurfaceVariant,
      );
      if (style == NavBarStyle.ios && isSelected) {
        icon = SvgIcons.call(
          filled: true,
          context: context,
          color: Colors.white,
        );
      } else if (style == NavBarStyle.genz && isSelected) {
        icon = SvgIcons.call(
          filled: true,
          context: context,
          color: Colors.white,
        );
      }
    } else {
      // 'You'
      icon = Icon(
        isSelected ? Icons.person : Icons.person_outline,
        color:
            isSelected && style != NavBarStyle.ios && style != NavBarStyle.genz
            ? color
            : theme.colorScheme.onSurfaceVariant,
      );
      if (style == NavBarStyle.ios && isSelected) {
        icon = Icon(Icons.person, color: Colors.white);
      } else if (style == NavBarStyle.genz && isSelected) {
        icon = Icon(Icons.person, color: Colors.white);
      }
    }

    if (style == NavBarStyle.modern) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (style == NavBarStyle.ios) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: icon,
      );
    }

    if (style == NavBarStyle.bubble) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Transform.scale(scale: isSelected ? 1.2 : 1.0, child: icon),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSelected ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isSelected ? 18 : 0,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (style == NavBarStyle.liquid) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              transform: isSelected
                  ? Matrix4.translationValues(0, -6, 0)
                  : Matrix4.identity(),
              child: Container(padding: const EdgeInsets.all(12), child: icon),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isSelected ? 14 : 0,
              child: isSelected
                  ? Text(
                      label,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    if (style == NavBarStyle.genz) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: icon,
      );
    }

    return Container(child: icon);
  }

  Widget _buildColorOption(BuildContext context, Color color, bool isSelected) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: theme.colorScheme.surface, width: 4)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: isSelected ? 12 : 6,
            offset: isSelected ? const Offset(0, 6) : const Offset(0, 3),
          ),
          if (isSelected)
            BoxShadow(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              blurRadius: 2,
              spreadRadius: 1,
            ),
        ],
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 32)
          : null,
    );
  }

  Widget _buildGradientOption(
    BuildContext context,
    List<Color> colors,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: theme.colorScheme.surface, width: 4)
            : null,
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.4),
            blurRadius: isSelected ? 12 : 6,
            offset: isSelected ? const Offset(0, 6) : const Offset(0, 3),
          ),
          if (isSelected)
            BoxShadow(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              blurRadius: 2,
              spreadRadius: 1,
            ),
        ],
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 32)
          : null,
    );
  }
}
