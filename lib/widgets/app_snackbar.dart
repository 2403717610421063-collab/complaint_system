import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum SnackType { success, error, warning, info }

class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cfg = _config(type);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cfg.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
          backgroundColor: cfg.color,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          elevation: 8,
        ),
      );
  }

  static _SnackCfg _config(SnackType type) {
    switch (type) {
      case SnackType.success: return _SnackCfg(AppColors.success, Icons.check_circle_rounded);
      case SnackType.error:   return _SnackCfg(AppColors.error,   Icons.error_rounded);
      case SnackType.warning: return _SnackCfg(AppColors.warning,  Icons.warning_rounded);
      case SnackType.info:    return _SnackCfg(AppColors.primary,  Icons.info_rounded);
    }
  }
}

class _SnackCfg {
  final Color color;
  final IconData icon;
  const _SnackCfg(this.color, this.icon);
}
