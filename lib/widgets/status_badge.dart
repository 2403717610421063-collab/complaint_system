import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;

  const StatusBadge({
    super.key,
    required this.label,
  });

  Color _statusColor(String status) {
    final s = status.toLowerCase();

    if (s.contains('resolved')) return AppColors.success;
    if (s.contains('approved')) return Colors.blue;
    if (s.contains('rejected')) return Colors.red;
    if (s.contains('escalated')) return AppColors.warning;

    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(label);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}