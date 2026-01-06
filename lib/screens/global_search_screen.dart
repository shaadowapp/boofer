import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../models/user_model.dart';
import '../services/connection_service.dart';
import '../services/friendship_service.dart';
import '../services/user_service.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/friendship_status_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ConnectionService _connectionService = ConnectionService.instance;
  List<Friend> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _searchType = 'username'; // 'username' or 'number'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = false;
    });

    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock search results based on query
    final results = _generateSearchResults(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  List<Friend> _generateSearchResults(String query) {
    // Mock global users for search results
    final allUsers = [
      Friend(
        id: 'search_1',
        name: 'Alex Johnson',
        handle: 'Alex_NYC',
        virtualNumber: '555-901-2345',
        lastMessage: 'New York, USA • Online now',
        lastMessageTime: DateTime.now(),
        isOnline: true,
      ),
      Friend(
        id: 'search_2',
        name: 'Sarah Williams',
        handle: 'Sarah_London',
        virtualNumber: '555-902-3456',
        lastMessage: 'London, UK • Active 5m ago',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        isOnline: false,
      ),
      Friend(
        id: 'search_3',
        name: 'Mike Tanaka',
        handle: 'Mike_Tokyo',
        virtualNumber: '555-903-4567',
        lastMessage: 'Tokyo, Japan • Online now',
        lastMessageTime: DateTime.now(),
        isOnline: true,
      ),
      Friend(
        id: 'search_4',
        name: 'Emma Dubois',
        handle: 'Emma_Paris',
        virtualNumber: '555-904-5678',
        lastMessage: 'Paris, France • Active 1h ago',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        isOnline: false,
      ),
      Friend(
        id: 'search_5',
        name: 'Carlos Silva',
        handle: 'Carlos_Brazil',
        virtualNumber: '555-905-6789',
        lastMessage: 'São Paulo, Brazil • Online now',
        lastMessageTime: DateTime.now(),
        isOnline: true,
      ),
    ];

    // Filter based on search query and type
    return allUsers.where((user) {
      final queryLower = query.toLowerCase();
      if (_searchType == 'username') {
        return user.name.toLowerCase().contains(queryLower) ||
               user.handle.toLowerCase().contains(queryLower);
      } else {
        return user.virtualNumber.contains(query);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                // Search type toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSearchTypeButton(
                          'Username',
                          'username',
                          Icons.person,
                        ),
                      ),
                      Expanded(
                        child: _buildSearchTypeButton(
                          'Virtual Number',
                          'number',
                          Icons.phone,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _searchType == 'username' 
                        ? 'Search by username...' 
                        : 'Search by virtual number...',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(
                      _searchType == 'username' ? Icons.person_search : Icons.phone_in_talk,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults.clear();
                                _hasSearched = false;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  onChanged: (value) => setState(() {}),
                  onSubmitted: _performSearch,
                ),
                
                const SizedBox(height: 12),
                
                // Search button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _searchController.text.trim().isNotEmpty
                        ? () => _performSearch(_searchController.text)
                        : null,
                    icon: _isSearching 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isSearching ? 'Searching...' : 'Search Globally'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Results section
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTypeButton(String label, String type, IconData icon) {
    final isSelected = _searchType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _searchType = type;
          _searchResults.clear();
          _hasSearched = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching globally...'),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildSearchSuggestions();
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different ${_searchType == 'username' ? 'username' : 'virtual number'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to find people on Boofer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildSuggestionCard(
            icon: Icons.person_search,
            title: 'Search by Username',
            description: 'Find people using their unique usernames like "Alex_NYC" or "Sarah_London"',
            example: 'Example: Alex_NYC',
          ),
          
          const SizedBox(height: 16),
          
          _buildSuggestionCard(
            icon: Icons.phone_in_talk,
            title: 'Search by Virtual Number',
            description: 'Connect using virtual phone numbers for complete privacy',
            example: 'Example: 555-901-2345',
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Privacy Features',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildFeatureItem(
            icon: Icons.security,
            title: 'Complete Privacy',
            description: 'No real phone numbers or personal info required',
          ),
          
          _buildFeatureItem(
            icon: Icons.public,
            title: 'Global Reach',
            description: 'Connect with anyone, anywhere in the world',
          ),
          
          _buildFeatureItem(
            icon: Icons.flash_on,
            title: 'Instant Connection',
            description: 'Start chatting immediately after connecting',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required IconData icon,
    required String title,
    required String description,
    required String example,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    example,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Friend user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: UserProfileCard(
              user: user.toUser(),
              showOnlineStatus: true,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _connectWithUser(user),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  void _connectWithUser(Friend user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect with ${user.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${user.formattedHandle}'),
            Text('Virtual Number: ${user.virtualNumber}'),
            const SizedBox(height: 16),
            const Text(
              'Send a connection request to start chatting?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendConnectionRequest(user);
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _sendConnectionRequest(Friend user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Follow request sent to ${user.name}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to pending requests or chat
          },
        ),
      ),
    );
  }
}