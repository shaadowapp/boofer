import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/svg_icons.dart';

class DialpadScreen extends StatefulWidget {
  const DialpadScreen({super.key});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  String _phoneNumber = '';
  final List<Map<String, String>> _dialpadButtons = [
    {'number': '1', 'letters': ''},
    {'number': '2', 'letters': 'ABC'},
    {'number': '3', 'letters': 'DEF'},
    {'number': '4', 'letters': 'GHI'},
    {'number': '5', 'letters': 'JKL'},
    {'number': '6', 'letters': 'MNO'},
    {'number': '7', 'letters': 'PQRS'},
    {'number': '8', 'letters': 'TUV'},
    {'number': '9', 'letters': 'WXYZ'},
    {'number': '*', 'letters': ''},
    {'number': '0', 'letters': '+'},
    {'number': '#', 'letters': ''},
  ];

  void _onNumberPressed(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      _phoneNumber += number;
    });
  }

  void _onDeletePressed() {
    HapticFeedback.lightImpact();
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  void _onCallPressed() {
    if (_phoneNumber.isNotEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling $_phoneNumber...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onVideoCallPressed() {
    if (_phoneNumber.isNotEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video calling $_phoneNumber...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatPhoneNumber(String number) {
    if (number.isEmpty) return number;
    
    // Simple formatting for demo purposes
    String formatted = number;
    if (number.length >= 3) {
      formatted = '(${number.substring(0, 3)}) ${number.substring(3)}';
    }
    if (number.length >= 6) {
      formatted = '(${number.substring(0, 3)}) ${number.substring(3, 6)}-${number.substring(6)}';
    }
    
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Dialpad'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Phone number display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: Text(
                    _phoneNumber.isEmpty ? 'Enter number' : _formatPhoneNumber(_phoneNumber),
                    style: TextStyle(
                      fontSize: _phoneNumber.isEmpty ? 18 : 24,
                      fontWeight: FontWeight.w500,
                      color: _phoneNumber.isEmpty 
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_phoneNumber.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Video call button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: FloatingActionButton(
                          onPressed: _onVideoCallPressed,
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          heroTag: 'video_call',
                          child: SvgIcons.sized(SvgIcons.videoCall, 24, color: Colors.white),
                        ),
                      ),
                      // Voice call button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: FloatingActionButton(
                          onPressed: _onCallPressed,
                          backgroundColor: const Color(0xFF4CAF50),
                          heroTag: 'voice_call',
                          child: SvgIcons.sized(SvgIcons.voiceCall, 24, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Spacer to push content to bottom
          const Expanded(child: SizedBox()),
          
          // Top actions (backspace and add user) - just above dialpad
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Add contact button
                IconButton(
                  onPressed: _phoneNumber.isNotEmpty ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add contact functionality coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } : null,
                  icon: SvgIcons.sized(
                    SvgIcons.addUser,
                    28,
                    color: _phoneNumber.isNotEmpty 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                
                // Delete button
                IconButton(
                  onPressed: _phoneNumber.isNotEmpty ? _onDeletePressed : null,
                  icon: SvgIcons.sized(
                    SvgIcons.backspace,
                    28,
                    color: _phoneNumber.isNotEmpty 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          
          // Dialpad at bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _dialpadButtons.length,
              itemBuilder: (context, index) {
                final button = _dialpadButtons[index];
                return _buildDialpadButton(
                  number: button['number']!,
                  letters: button['letters']!,
                );
              },
            ),
          ),
          
          // Bottom spacing
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDialpadButton({
    required String number,
    required String letters,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}