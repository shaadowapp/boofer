import 'package:flutter/material.dart';
import '../utils/svg_icons.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_end_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No call history found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTile({
    required BuildContext context,
    required String name,
    required String time,
    required CallType type,
    required bool isVideo,
  }) {
    String callIconName;
    Color iconColor;

    switch (type) {
      case CallType.incoming:
        callIconName = SvgIcons.callReceived;
        iconColor = const Color(0xFF4CAF50);
        break;
      case CallType.outgoing:
        callIconName = SvgIcons.callMade;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case CallType.missed:
        callIconName = SvgIcons.callReceived;
        iconColor = Colors.red;
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Text(
          name.split(' ').map((e) => e[0]).take(2).join(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      title: Text(
        name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: type == CallType.missed
              ? Colors.red
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          SvgIcons.sized(callIconName, 16, color: iconColor),
          const SizedBox(width: 4),
          Text(time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: IconButton(
        icon: isVideo
            ? SvgIcons.sized(
                SvgIcons.videoCall,
                24,
                color: Theme.of(context).colorScheme.primary,
              )
            : SvgIcons.sized(
                SvgIcons.voiceCall,
                24,
                color: Theme.of(context).colorScheme.primary,
              ),
        onPressed: () {
          // Start call
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calling $name...'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

enum CallType { incoming, outgoing, missed }
