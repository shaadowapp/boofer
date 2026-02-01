import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friendship_service.dart';
import '../services/user_service.dart';

/// Widget that shows friendship status and provides actions
class FriendshipStatusWidget extends StatefulWidget {
  final User user;
  final VoidCallback? onStatusChanged;

  const FriendshipStatusWidget({
    super.key,
    required this.user,
    this.onStatusChanged,
  });

  @override
  State<FriendshipStatusWidget> createState() => _FriendshipStatusWidgetState();
}

class _FriendshipStatusWidgetState extends State<FriendshipStatusWidget> {
  final FriendshipService _friendshipService = FriendshipService.instance;
  FriendshipStatus _status = FriendshipStatus.none;
  bool _loading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFriendshipStatus();
  }

  Future<void> _loadFriendshipStatus() async {
    final currentUser = await UserService.getCurrentUser();
    if (currentUser == null) return;

    setState(() {
      _currentUserId = currentUser.id;
      _loading = true;
    });

    final status = await _friendshipService.getFriendshipStatus(
      currentUser.id,
      widget.user.id,
    );

    if (mounted) {
      setState(() {
        _status = status;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _currentUserId == null) {
      return const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Don't show status for current user
    if (_currentUserId == widget.user.id) {
      return const SizedBox.shrink();
    }

    return _buildStatusWidget();
  }

  Widget _buildStatusWidget() {
    switch (_status) {
      case FriendshipStatus.none:
        return _buildSendRequestButton();
      case FriendshipStatus.requestSent:
        return _buildRequestSentWidget();
      case FriendshipStatus.requestReceived:
        return _buildRequestReceivedWidget();
      case FriendshipStatus.friends:
        return _buildFriendsWidget();
      case FriendshipStatus.blocked:
        return _buildBlockedWidget();
    }
  }

  Widget _buildSendRequestButton() {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _sendFriendRequest,
      icon: _loading 
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_add, size: 18),
      label: Text(_loading ? 'Sending...' : 'Follow'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRequestSentWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'Request Sent',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestReceivedWidget() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _declineRequest,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Decline'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade600,
            side: BorderSide(color: Colors.red.shade600),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _loading ? null : _acceptRequest,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Accept'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            'Friends',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Text(
            'Blocked',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null) return;

    setState(() => _loading = true);

    final success = await _friendshipService.sendFriendRequest(
      _currentUserId!,
      widget.user.id,
      message: 'Hi! I\'d like to connect with you.',
    );

    if (mounted) {
      setState(() => _loading = false);

      if (success) {
        setState(() => _status = FriendshipStatus.requestSent);
        widget.onStatusChanged?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Follow request sent to ${widget.user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send follow request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest() async {
    // This would need the request ID - for now, just reload status
    await _loadFriendshipStatus();
    widget.onStatusChanged?.call();
  }

  Future<void> _declineRequest() async {
    // This would need the request ID - for now, just reload status
    await _loadFriendshipStatus();
    widget.onStatusChanged?.call();
  }
}