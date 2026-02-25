import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/archive_settings_provider.dart';

class ArchiveSettingsScreen extends StatefulWidget {
  const ArchiveSettingsScreen({super.key});

  @override
  State<ArchiveSettingsScreen> createState() => _ArchiveSettingsScreenState();
}

class _ArchiveSettingsScreenState extends State<ArchiveSettingsScreen> {
  bool _isPositionSectionExpanded = false;
  bool _isBehaviorSectionExpanded = false;
  final TextEditingController _searchTriggerController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the search trigger controller with current value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final archiveSettings = Provider.of<ArchiveSettingsProvider>(
        context,
        listen: false,
      );
      _searchTriggerController.text = archiveSettings.archiveSearchTrigger;
    });
  }

  @override
  void dispose() {
    _searchTriggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<ArchiveSettingsProvider>(
        builder: (context, archiveSettings, child) {
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('Archive Settings'),
                centerTitle: true,
                backgroundColor: theme.colorScheme.surface,
                scrolledUnderElevation: 0,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Archive Button Position Section
                    _buildSectionCard(
                      context,
                      title: 'Archive Button Position',
                      icon: Icons.archive_outlined,
                      color: Colors.orange,
                      isExpanded: _isPositionSectionExpanded,
                      onToggle: () {
                        setState(() {
                          _isPositionSectionExpanded =
                              !_isPositionSectionExpanded;
                        });
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Choose where the archive button appears in the chat list',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...ArchiveButtonPosition.values.map((position) {
                          return Column(
                            children: [
                              RadioListTile<ArchiveButtonPosition>(
                                title: Text(
                                  archiveSettings.getPositionDisplayName(
                                    position,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  _getPositionDescription(position),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                value: position,
                                groupValue:
                                    archiveSettings.archiveButtonPosition,
                                onChanged: (value) {
                                  if (value != null) {
                                    archiveSettings.setArchiveButtonPosition(
                                      value,
                                    );
                                  }
                                },
                                contentPadding: EdgeInsets.zero,
                                activeColor: theme.colorScheme.primary,
                              ),
                              if (position == ArchiveButtonPosition.hidden &&
                                  archiveSettings.archiveButtonPosition ==
                                      ArchiveButtonPosition.hidden) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  child: TextField(
                                    controller: _searchTriggerController,
                                    decoration: InputDecoration(
                                      labelText: 'Search Trigger',
                                      hintText: 'e.g., archive',
                                      helperText:
                                          'Type to find hidden archives',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {});
                                      final trimmedValue = value.trim();
                                      if (trimmedValue.isNotEmpty) {
                                        archiveSettings.setArchiveSearchTrigger(
                                          trimmedValue,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Preview Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.05,
                          ),
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
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.preview_outlined,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Preview',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPreview(
                            context,
                            archiveSettings.archiveButtonPosition,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Archive Behavior Section
                    _buildSectionCard(
                      context,
                      title: 'Archive Behavior',
                      icon: Icons.lock_outline,
                      color: Colors.purple,
                      isExpanded: _isBehaviorSectionExpanded,
                      onToggle: () {
                        setState(() {
                          _isBehaviorSectionExpanded =
                              !_isBehaviorSectionExpanded;
                        });
                      },
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Keep chats archived',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Archived chats remain archived when receiving new messages',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          value: archiveSettings.keepChatsArchived,
                          onChanged: (value) {
                            archiveSettings.setKeepChatsArchived(value);
                          },
                          contentPadding: EdgeInsets.zero,
                          activeColor: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  String _getPositionDescription(ArchiveButtonPosition position) {
    switch (position) {
      case ArchiveButtonPosition.topOfChats:
        return 'Shows archive button at the top of the chat list';
      case ArchiveButtonPosition.bottomOfChats:
        return 'Shows archive button at the bottom of the chat list';
      case ArchiveButtonPosition.topNavbarMoreOptions:
        return 'Archive button accessible via top navbar menu';
      case ArchiveButtonPosition.hidden:
        return 'Archive button hidden, accessible via search trigger';
    }
  }

  Widget _buildPreview(BuildContext context, ArchiveButtonPosition position) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Mock navbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Boofer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (position == ArchiveButtonPosition.topNavbarMoreOptions)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                else
                  const Icon(Icons.more_vert, color: Colors.white, size: 16),
              ],
            ),
          ),

          // Mock chat list
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Top archive button
                if (position == ArchiveButtonPosition.topOfChats)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.archive,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('Archived', style: TextStyle(fontSize: 12)),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                          size: 16,
                        ),
                      ],
                    ),
                  ),

                // Mock chat items
                ...List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Friend ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Last message...',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom archive button
                if (position == ArchiveButtonPosition.bottomOfChats)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.archive,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('Archived', style: TextStyle(fontSize: 12)),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                          size: 16,
                        ),
                      ],
                    ),
                  ),

                // Hidden option preview
                if (position == ArchiveButtonPosition.hidden)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Type "${_searchTriggerController.text}" to access',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
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
    );
  }
}
