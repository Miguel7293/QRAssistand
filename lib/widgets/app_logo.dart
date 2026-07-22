import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Branded app emblem: a garnet badge with a QR motif and a gold graduation
/// cap accent. Sized by [size]; use [showWordmark] to append the app name.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const AppLogo({super.key, this.size = 72, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.garnetGradient,
              borderRadius: BorderRadius.circular(size * 0.28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.garnet.withValues(alpha: 0.35),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.10),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.qr_code_2_rounded,
                  color: Colors.white, size: size * 0.62),
            ),
          ),
          Positioned(
            right: -size * 0.06,
            top: -size * 0.06,
            child: Container(
              padding: EdgeInsets.all(size * 0.10),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_rounded,
                  color: AppColors.garnetDark, size: size * 0.24),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        SizedBox(height: size * 0.22),
        Text(
          'AsistenciaUNA',
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.garnet,
          ),
        ),
        Text(
          'Universidad Nacional del Altiplano',
          style: TextStyle(
            fontSize: size * 0.15,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
