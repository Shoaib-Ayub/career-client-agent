import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/retry_button.dart';
import 'package:flutter/material.dart' as material;

class ErrorWidget extends material.StatelessWidget {
  const ErrorWidget({
    required this.onRetry,
    this.message = AppStrings.networkErrorMessage,
    super.key,
  });

  final material.VoidCallback onRetry;
  final String message;

  @override
  material.Widget build(material.BuildContext context) {
    final textTheme = material.Theme.of(context).textTheme;

    return material.Center(
      child: material.Padding(
        padding: const material.EdgeInsets.all(AppSizes.spaceLg),
        child: material.Column(
          mainAxisSize: material.MainAxisSize.min,
          children: [
            const material.Icon(
              AppIcons.emptyState,
              size: AppSizes.emptyStateIconSize,
              color: AppColors.navigationUnselected,
            ),
            const material.SizedBox(height: AppSizes.spaceMd),
            material.Text(
              AppStrings.networkErrorTitle,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: material.FontWeight.bold,
              ),
              textAlign: material.TextAlign.center,
            ),
            const material.SizedBox(height: AppSizes.spaceXs),
            material.Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: material.TextAlign.center,
            ),
            const material.SizedBox(height: AppSizes.spaceLg),
            RetryButton(onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
