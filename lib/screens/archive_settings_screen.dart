import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/archive_settings_provider.dart';
import '../l10n/app_localizations.dart';

class ArchiveSettingsScreen extends StatefulWidget {
  const ArchiveSettingsScreen({super.key});

  @override
  State<ArchiveSettingsScreen> createState() => _ArchiveSettingsScreenState();
}

class _ArchiveSettingsScreenState extends State<ArchiveSettingsScreen> {
  bool _isPositionSectionExpanded = false;
  bool _isBehaviorSectionExpanded = false;
  final TextEditingController _searchTriggerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the search trigger controller with current value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final archiveSettings = Provider.of<ArchiveSettingsProvider>(context, listen: false);
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
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: const Text('Archive Settings'),
        centerTitle: true,
      ),
      body: Consumer<ArchiveSettingsProvider>(
        builder: (context, archiveSettings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Archive Button Position Section (Collapsible)
              Card(
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isPositionSectionExpanded = !_isPositionSectionExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.archive,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Archive Button Position',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              _isPositionSectionExpanded 
                                  ? Icons.keyboard_arrow_up 
                                  : Icons.keyboard_arrow_down,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isPositionSectionExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose where the archive button appears in the chat list',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Position Options
                            ...ArchiveButtonPosition.values.map((position) {
                              return Column(
                                children: [
                                  RadioListTile<ArchiveButtonPosition>(
                                    title: Text(archiveSettings.getPositionDisplayName(position)),
                                    subtitle: Text(_getPositionDescription(position)),
                                    value: position,
                                    groupValue: archiveSettings.archiveButtonPosition,
                                    onChanged: (value) {
                                      if (value != null) {
                                        archiveSettings.setArchiveButtonPosition(value);
                                      }
                                    },
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  // Show search trigger input for hidden option
                                  if (position == ArchiveButtonPosition.hidden && 
                                      archiveSettings.archiveButtonPosition == ArchiveButtonPosition.hidden) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32, right: 16, bottom: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Search Trigger',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _searchTriggerController,
                                            decoration: InputDecoration(
                                              hintText: 'Enter trigger text (e.g., archive, 📁, a/b/d)',
                                              helperText: 'Type this in the search bar to open archived chats',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 12, 
                                                vertical: 8,
                                              ),
                                            ),
                                            onChanged: (value) {
                                              if (value.isNotEmpty) {
                                                archiveSettings.setArchiveSearchTrigger(value);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Preview Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.preview,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Preview',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPreview(context, archiveSettings.archiveButtonPosition),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Archive Behavior Section (Collapsible)
              Card(
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isBehaviorSectionExpanded = !_isBehaviorSectionExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Archive Behavior',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              _isBehaviorSectionExpanded 
                                  ? Icons.keyboard_arrow_up 
                                  : Icons.keyboard_arrow_down,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isBehaviorSectionExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SwitchListTile(
                          title: const Text('Keep chats archived'),
                          subtitle: const Text('Archived chats remain archived when receiving new messages'),
                          value: archiveSettings.keepChatsArchived,
                          onChanged: (value) {
                            archiveSettings.setKeepChatsArchived(value);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
                  const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 16,
                  ),
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                        const Text(
                          'Archived',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                
                // Mock chat items
                ...List.generate(3, (index) => Container(
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
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Last message...',
                              style: TextStyle(
                                fontSize: 8,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                
                // Bottom archive button
                if (position == ArchiveButtonPosition.bottomOfChats)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                        const Text(
                          'Archived',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Type "${_searchTriggerController.text}" to access',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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