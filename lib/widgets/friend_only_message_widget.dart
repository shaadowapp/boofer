import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friendship_service.dart';
import '../widgets/friendship_status_widget.dart';

/// Widget shown when trying to message someone who isn't a friend
class FriendOnlyMessageWidget extends StatelessWidget {
  final User user;
  final VoidCallback? onFriendRequestSent;

  const FriendOnlyMessageWidget({
    super.key,
    required this.user,
    this.onFriendRequestSent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Friends Only',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can only send messages to friends. Send a friend request to ${user.displayName} to start chatting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FriendshipStatusWidget(
            user: user,
            onStatusChanged: onFriendRequestSent,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}