import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool showLabel;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  const ThemeToggleButton({
    super.key,
    this.showLabel = false,
    this.iconSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        if (showLabel) {
          return TextButton.icon(
            onPressed: () => themeProvider.toggleTheme(),
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              size: iconSize,
            ),
            label: Text(
              themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
            ),
            style: TextButton.styleFrom(
              padding: padding,
            ),
          );
        } else {
          return IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              size: iconSize,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: themeProvider.isDarkMode 
                ? 'Switch to Light Mode' 
                : 'Switch to Dark Mode',
            padding: padding,
          );
        }
      },
    );
  }
}

class ThemeToggleSwitch extends StatelessWidget {
  final String? label;
  final bool showIcons;

  const ThemeToggleSwitch({
    super.key,
    this.label,
    this.showIcons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcons) ...[
              Icon(
                Icons.light_mode,
                size: 20,
                color: !themeProvider.isDarkMode 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 8),
            ],
            if (label != null) ...[
              Text(
                label!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
            ],
            Switch(
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
              thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.dark_mode, size: 16);
                  }
                  return const Icon(Icons.light_mode, size: 16);
                },
              ),
            ),
            if (showIcons) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.dark_mode,
                size: 20,
                color: themeProvider.isDarkMode 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ],
          ],
        );
      },
    );
  }
}

class ThemeToggleCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const ThemeToggleCard({
    super.key,
    this.title,
    this.subtitle,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Card(
          margin: margin ?? const EdgeInsets.all(8.0),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? (themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}