import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.summaryIconContainerSize,
              height: AppSizes.summaryIconContainerSize,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              ),
              child: Icon(
                icon,
                color: AppColors.onPrimary,
                size: AppSizes.bottomNavigationIconSize,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
