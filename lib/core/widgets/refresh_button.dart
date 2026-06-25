import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

class RefreshButton extends StatelessWidget {
  const RefreshButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: AppSizes.refreshProgressSize,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: AppSizes.refreshProgressStrokeWidth,
              ),
            )
          : const Icon(AppIcons.refresh),
      label: Text(isLoading ? AppStrings.refreshing : AppStrings.refresh),
    );
  }
}
