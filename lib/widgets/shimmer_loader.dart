import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shimmer complaint card skeleton loader
class ComplaintCardShimmer extends StatelessWidget {
  const ComplaintCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 40, height: 40, borderRadius: AppRadius.md),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: double.infinity, height: 14, borderRadius: 6),
                    const SizedBox(height: 8),
                    ShimmerBox(width: 140, height: 12, borderRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShimmerBox(width: 70, height: 26, borderRadius: AppRadius.pill),
            ],
          ),
          const SizedBox(height: 14),
          ShimmerBox(width: double.infinity, height: 12, borderRadius: 6),
          const SizedBox(height: 6),
          ShimmerBox(width: 200, height: 12, borderRadius: 6),
          const SizedBox(height: 14),
          Row(
            children: [
              ShimmerBox(width: 80, height: 24, borderRadius: AppRadius.pill),
              const SizedBox(width: 8),
              ShimmerBox(width: 80, height: 24, borderRadius: AppRadius.pill),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmer stat card skeleton
class StatCardShimmer extends StatelessWidget {
  const StatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 36, height: 36, borderRadius: 10),
          const SizedBox(height: 12),
          ShimmerBox(width: 50, height: 22, borderRadius: 6),
          const SizedBox(height: 6),
          ShimmerBox(width: 80, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}
