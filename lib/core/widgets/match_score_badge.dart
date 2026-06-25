import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.matchBadgeHorizontalPadding,
        vertical: AppSizes.matchBadgeVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppSizes.badgeRadius),
      ),
      child: Text(
        AppStrings.matchScore(score),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
