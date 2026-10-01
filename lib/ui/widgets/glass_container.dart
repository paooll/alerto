import 'dart:ui';

import 'package:flutter/material.dart';

/// iOS-style frosted glass container. Reserved for layered chrome (app bar,
/// bottom nav, banners) where content scrolls underneath — not for cards.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 0,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xCC101A30)
                : const Color(0xD9FFFFFF),
            border: Border(
              bottom: isDark
                  ? BorderSide(color: Colors.white.withOpacity(0.06))
                  : BorderSide(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
