import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class WritePostScreen extends StatefulWidget {
  final User currentUser;

  const WritePostScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  String? _selectedImageType;
  bool _isPosting = false;

  final List<Map<String, dynamic>> _imageOptions = [
    {
      'type': 'gradient_purple',
      'name': 'Purple Gradient',
      'colors': [Colors.purple, Colors.pink],
      'icon': Icons.gradient,
    },
    {
      'type': 'gradient_blue',
      'name': 'Blue Gradient',
      'colors': [Colors.blue, Colors.cyan],
      'icon': Icons.water,
    },
    {
      'type': 'gradient_orange',
      'name': 'Orange Gradient',
      'colors': [Colors.orange, Colors.red],
      'icon': Icons.wb_sunny,
    },
    {
      'type': 'pattern',
      'name': 'Pattern Design',
      'colors': [Colors.indigo, Colors.teal],
      'icon': Icons.pattern,
    },
    {
      'type': 'gradient_green',
      'name': 'Green Gradient',
      'colors': [Colors.green, Colors.teal],
      'icon': Icons.nature,
    },
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    if (_captionController.text.trim().isEmpty && _selectedImageType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a caption or select an image style'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    // Simulate posting delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isPosting = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post published successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      // Go back to home screen
      Navigator.pop(context, {
        'caption': _captionController.text.trim(),
        'imageType': _selectedImageType,
        'author': widget.currentUser,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _publishPost,
            child: _isPosting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Post',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            _buildUserInfo(),
            const SizedBox(height: 24),
            
            // Caption input
            _buildCaptionInput(),
            const SizedBox(height: 24),
            
            // Image selection
            _buildImageSelection(),
            const SizedBox(height: 24),
            
            // Preview
            if (_selectedImageType != null || _captionController.text.isNotEmpty)
              _buildPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(
            widget.currentUser.initials,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.currentUser.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.currentUser.formattedHandle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s on your mind?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _captionController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Share your thoughts, experiences, or moments...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          onChanged: (value) {
            setState(() {}); // Rebuild to update preview
          },
        ),
      ],
    );
  }

  Widget _buildImageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Image Style',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a visual style for your post',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: _imageOptions.length,
          itemBuilder: (context, index) {
            final option = _imageOptions[index];
            final isSelected = _selectedImageType == option['type'];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImageType = isSelected ? null : option['type'];
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: option['colors'],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option['icon'],
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            option['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        widget.currentUser.initials,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser.displayName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Just now',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Preview image
              if (_selectedImageType != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildPreviewImage(),
                  ),
                ),
              
              // Preview caption
              if (_captionController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.currentUser.displayName} ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: _captionController.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewImage() {
    final option = _imageOptions.firstWhere(
      (opt) => opt['type'] == _selectedImageType,
      orElse: () => _imageOptions[0],
    );
    
    if (_selectedImageType == 'pattern') {
      return _buildPatternPreview(option['colors']);
    } else {
      return _buildGradientPreview(option['colors'], option['icon']);
    }
  }

  Widget _buildGradientPreview(List<Color> colors, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.currentUser.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternPreview(List<Color> colors) {
    final random = Random(42); // Fixed seed for consistent preview
    
    return Container(
      decoration: BoxDecoration(
        color: colors[0],
      ),
      child: Stack(
        children: [
          // Pattern background
          ...List.generate(15, (index) {
            return Positioned(
              left: random.nextDouble() * 300,
              top: random.nextDouble() * 200,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '📸 ${widget.currentUser.displayName}\'s Post',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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