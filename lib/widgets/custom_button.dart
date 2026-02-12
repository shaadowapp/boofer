import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/appearance_provider.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 48.0,
    this.padding,
    this.borderRadius,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearanceProvider = Provider.of<AppearanceProvider>(
      context,
      listen: false,
    );

    // Only apply gradient if it's enabled and we're using the default background color
    final useGradient =
        appearanceProvider.useGradientAccent && backgroundColor == null;
    final buttonBorderRadius =
        borderRadius ?? BorderRadius.circular(appearanceProvider.cornerRadius);

    return Container(
      width: width,
      height: height,
      decoration: useGradient
          ? BoxDecoration(
              gradient: appearanceProvider.getAccentGradient(),
              borderRadius: buttonBorderRadius,
              boxShadow: [
                BoxShadow(
                  color:
                      (appearanceProvider.getAccentGradient()?.colors.first ??
                              theme.colorScheme.primary)
                          .withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: useGradient
              ? Colors.transparent
              : (backgroundColor ?? theme.colorScheme.primary),
          foregroundColor:
              textColor ??
              (useGradient ? Colors.white : theme.colorScheme.onPrimary),
          shadowColor: useGradient ? Colors.transparent : null,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          elevation: useGradient ? 0 : 2,
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ??
                        (useGradient
                            ? Colors.white
                            : theme.colorScheme.onPrimary),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          textColor ??
                          (useGradient
                              ? Colors.white
                              : theme.colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
