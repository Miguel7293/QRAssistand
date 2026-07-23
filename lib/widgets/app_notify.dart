import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum NotifyType { success, error, info, warning }

/// Styled, floating notifications used across the app instead of raw
/// SnackBars. High-contrast card with a colored icon chip, rounded corners
/// and a shadow so it reads clearly over any screen.
class AppNotify {
  static void show(
    BuildContext context,
    String message, {
    NotifyType type = NotifyType.info,
    String? title,
  }) {
    final (color, icon, defaultTitle) = _style(type);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        content: _Card(
          color: color,
          icon: icon,
          title: title ?? defaultTitle,
          message: message,
        ),
      ),
    );
  }

  static void success(BuildContext c, String m, {String? title}) =>
      show(c, m, type: NotifyType.success, title: title);
  static void error(BuildContext c, String m, {String? title}) =>
      show(c, m, type: NotifyType.error, title: title);
  static void info(BuildContext c, String m, {String? title}) =>
      show(c, m, type: NotifyType.info, title: title);
  static void warning(BuildContext c, String m, {String? title}) =>
      show(c, m, type: NotifyType.warning, title: title);

  static (Color, IconData, String) _style(NotifyType t) => switch (t) {
        NotifyType.success => (
            AppColors.success,
            Icons.check_circle_rounded,
            'Listo'
          ),
        NotifyType.error => (
            AppColors.danger,
            Icons.error_rounded,
            'Ups'
          ),
        NotifyType.warning => (
            AppColors.gold,
            Icons.warning_amber_rounded,
            'Atención'
          ),
        NotifyType.info => (
            AppColors.garnet,
            Icons.info_rounded,
            'Información'
          ),
      };
}

class _Card extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  const _Card({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: color == AppColors.gold
                        ? AppColors.garnetDark
                        : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                      color: AppColors.ink, fontSize: 13, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
