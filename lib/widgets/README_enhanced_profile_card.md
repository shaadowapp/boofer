# Enhanced User Profile Card

The `EnhancedUserProfileCard` widget provides two display styles for showing user profiles:

## Grid Style
- Vertical layout with all elements centered
- Profile picture at the top
- Full name below the picture
- User handle (small text) below the name
- Virtual number below the handle
- Follow button at the bottom (full width)

```dart
EnhancedUserProfileCard(
  user: user,
  style: ProfileCardStyle.grid,
  onTap: () => _showUserProfile(user),
  showFollowButton: true,
)
```

## List Style
- Horizontal layout divided into 3 sections
- Section 1: Profile picture on the left
- Section 2: Full name with handle in parentheses, virtual number below
- Section 3: Follow button on the right

```dart
EnhancedUserProfileCard(
  user: user,
  style: ProfileCardStyle.list,
  onTap: () => _openChat(user),
  showFollowButton: true,
)
```

## Compact Version (Backwards Compatibility)
For backwards compatibility, `CompactUserProfileCard` is available and uses the list style:

```dart
CompactUserProfileCard(
  user: user,
  onTap: () => _openChat(user),
  showFollowButton: true,
)
```

## Properties
- `user`: The User object to display
- `style`: ProfileCardStyle.grid or ProfileCardStyle.list
- `onTap`: Callback when the card is tapped
- `onStatusChanged`: Callback when friendship status changes
- `showFollowButton`: Whether to show the follow/friend button
- `showOnlineStatus`: Whether to show online status indicator