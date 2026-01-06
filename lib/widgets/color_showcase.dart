import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ColorShowcase extends StatelessWidget {
  const ColorShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Color Palette'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: AppColors.brandAccent,
      ),
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Primary Colors',
              [
                _buildColorCard('Brand Accent (Electric Orchid)', AppColors.brandAccent, Colors.white),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Background Colors',
              [
                _buildColorCard(
                  isDark ? 'Dark Background (Off-Black)' : 'Light Background (Off-White)',
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
                _buildColorCard(
                  isDark ? 'Dark Surface (Nav/Cards)' : 'Light Surface (Pure White)',
                  isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Text Colors',
              [
                _buildColorCard(
                  'Primary Text',
                  isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                ),
                _buildColorCard(
                  'Secondary Text',
                  isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Chat Bubbles Demo',
              [
                _buildChatBubbleDemo(context),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Chat Bubble Colors',
              [
                _buildColorCard(
                  isDark ? 'Sender Bubble (Dark)' : 'Sender Bubble (Light)',
                  AppColors.senderBubble(isDark),
                  isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
                _buildColorCard(
                  isDark ? 'Receiver Bubble (Dark)' : 'Receiver Bubble (Light)',
                  AppColors.receiverBubble(isDark),
                  isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Status Colors',
              [
                _buildColorCard('Brand Accent Usage', AppColors.brandAccent, Colors.white),
                _buildColorCard('Warning', AppColors.warning, Colors.white),
                _buildColorCard('Danger', AppColors.danger, Colors.white),
                _buildColorCard('Info', AppColors.info, Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildColorCard(String name, Color color, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubbleDemo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // User message (right side) - using muted brand color
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, left: 50),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.senderBubble(isDark),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  'Hey! Check out our refined Electric Orchid theme! 💜',
                  style: TextStyle(
                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Other user message (left side) - using neutral contrast
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, right: 50),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.receiverBubble(isDark),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Perfect! The muted sender bubbles work great for large areas! ✨',
                  style: TextStyle(
                    color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Status indicator demo - using brand accent
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brandAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.brandAccent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.brandAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Unread Badge • Active Navigation',
                style: TextStyle(
                  color: AppColors.brandAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}