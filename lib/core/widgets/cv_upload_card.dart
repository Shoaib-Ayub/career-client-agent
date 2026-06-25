import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/features/profile/model/cv_document.dart';
import 'package:flutter/material.dart';

class CvUploadCard extends StatelessWidget {
  const CvUploadCard({
    required this.document,
    required this.isLoading,
    required this.onUpload,
    required this.onDelete,
    super.key,
  });

  final CvDocument? document;
  final bool isLoading;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasDocument = document != null;

    return ProfileCard(
      title: AppStrings.cvTitle,
      subtitle: AppStrings.cvSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.cv,
                size: AppSizes.cvIconSize,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSizes.spaceMd),
              Expanded(
                child: Text(
                  document?.fileName ?? AppStrings.noCvUploaded,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            AppStrings.supportedCvTypes,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spaceLg),
          Wrap(
            spacing: AppSizes.spaceSm,
            runSpacing: AppSizes.spaceSm,
            children: [
              FilledButton.icon(
                onPressed: isLoading ? null : onUpload,
                icon: const Icon(AppIcons.upload),
                label: Text(
                  hasDocument ? AppStrings.replaceCv : AppStrings.uploadCv,
                ),
              ),
              if (hasDocument)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onDelete,
                  icon: const Icon(AppIcons.delete),
                  label: const Text(AppStrings.deleteCv),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
