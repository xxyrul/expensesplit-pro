import 'dart:async';

import 'package:flutter/material.dart';

enum ModernToastType { success, error, info, warning }

class ModernBottomToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    ModernToastType type = ModernToastType.success,
  }) {
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color accentColor;
    final IconData icon;

    switch (type) {
      case ModernToastType.error:
        accentColor = theme.colorScheme.error;
        icon = Icons.error_outline_rounded;
        break;
      case ModernToastType.warning:
        accentColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case ModernToastType.info:
        accentColor = theme.colorScheme.secondary;
        icon = Icons.info_outline_rounded;
        break;
      case ModernToastType.success:
        accentColor = theme.colorScheme.primary;
        icon = Icons.check_circle_rounded;
        break;
    }

    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final scaffold = Scaffold.maybeOf(context);
    final hasBottomBar = scaffold?.widget.bottomNavigationBar != null;
    final bottomOffset = hasBottomBar ? 112.0 : 24.0;

    _activeEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottomOffset + MediaQuery.of(overlayContext).padding.bottom,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 14),
                      child: child,
                    ),
                  );
                },
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.22 : 0.10),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: accentColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_activeEntry!);
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      _activeEntry?.remove();
      _activeEntry = null;
    });
  }
}