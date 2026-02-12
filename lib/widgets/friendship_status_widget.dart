import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_request_service.dart';
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
  final FriendRequestService _friendRequestService =
      FriendRequestService.instance;
  String _relationshipStatus = 'none';
  String? _requestId;
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

    if (mounted) {
      setState(() {
        _currentUserId = currentUser.id;
        _loading = true;
      });
    }

    final relationData = await _friendRequestService.getRelationshipStatus(
      currentUser.id,
      widget.user.id,
    );

    if (mounted) {
      setState(() {
        _relationshipStatus = relationData['status'] as String;
        _requestId = relationData['requestId'] as String?;
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
    switch (_relationshipStatus) {
      case 'none':
        return _buildSendRequestButton();
      case 'request_sent':
        return _buildRequestSentWidget();
      case 'request_received':
        return _buildRequestReceivedWidget();
      case 'friends':
        return _buildFriendsWidget();
      case 'self':
        return const SizedBox.shrink();
      default:
        return _buildSendRequestButton();
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

  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null) return;

    setState(() => _loading = true);

    final success = await _friendRequestService.sendFriendRequest(
      fromUserId: _currentUserId!,
      toUserId: widget.user.id,
      message: 'Hi! I\'d like to connect with you.',
    );

    if (mounted) {
      if (success) {
        await _loadFriendshipStatus();
        widget.onStatusChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Follow request sent to ${widget.user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _loading = false);
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
    if (_currentUserId == null || _requestId == null) return;

    setState(() => _loading = true);

    final success = await _friendRequestService.acceptFriendRequest(
      requestId: _requestId!,
      userId: _currentUserId!,
    );

    if (mounted) {
      if (success) {
        await _loadFriendshipStatus();
        widget.onStatusChanged?.call();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _declineRequest() async {
    if (_currentUserId == null || _requestId == null) return;

    setState(() => _loading = true);

    final success = await _friendRequestService.rejectFriendRequest(
      requestId: _requestId!,
      userId: _currentUserId!,
    );

    if (mounted) {
      if (success) {
        await _loadFriendshipStatus();
        widget.onStatusChanged?.call();
      } else {
        setState(() => _loading = false);
      }
    }
  }
}
