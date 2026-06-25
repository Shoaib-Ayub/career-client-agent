import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/features/settings/model/backend_run_status.dart';
import 'package:flutter/material.dart';

class BackendRunStatusCard extends StatelessWidget {
  const BackendRunStatusCard({required this.status, super.key});

  final BackendRunStatus status;

  @override
  Widget build(BuildContext context) {
    final lastRun = status.lastRunTime;
    return ProfileCard(
      title: AppStrings.backendRunStatusTitle,
      subtitle: AppStrings.backendRunStatusDescription,
      trailing: const Icon(AppIcons.backendStatus, color: AppColors.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.lastBackendRunValue(
              lastRun == null
                  ? AppStrings.backendStatusUnavailable
                  : AppDateFormatter.dateTime(lastRun),
            ),
          ),
          const SizedBox(height: AppSizes.spaceMd),
          Text(AppStrings.dataSourceValue(status.sourceUsed)),
          const SizedBox(height: AppSizes.spaceSm),
          Text(AppStrings.recordsDownloadedValue(status.recordsDownloaded)),
          const SizedBox(height: AppSizes.spaceSm),
          Text(AppStrings.lastSyncStatusValue(status.syncStatus)),
          if (status.lastError != null) ...[
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              AppStrings.labeledValue(
                AppStrings.lastSyncError,
                status.lastError!,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ],
          const SizedBox(height: AppSizes.spaceMd),
          Wrap(
            spacing: AppSizes.spaceSm,
            runSpacing: AppSizes.spaceSm,
            children: [
              _StatusMetric(
                icon: AppIcons.jobs,
                label: AppStrings.totalJobsFound,
                value: status.totalJobs,
                color: AppColors.jobsAccent,
              ),
              _StatusMetric(
                icon: AppIcons.scholarships,
                label: AppStrings.totalScholarshipsFound,
                value: status.totalScholarships,
                color: AppColors.scholarshipsAccent,
              ),
              _StatusMetric(
                icon: AppIcons.governmentJobs,
                label: AppStrings.totalGovernmentJobsFound,
                value: status.totalGovernmentJobs,
                color: AppColors.governmentAccent,
              ),
              _StatusMetric(
                icon: AppIcons.clientLeads,
                label: AppStrings.totalClientLeadsFound,
                value: status.totalClientLeads,
                color: AppColors.clientsAccent,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceLg),
          Row(
            children: [
              Icon(
                status.failedSources.isEmpty
                    ? AppIcons.successStatus
                    : AppIcons.failedSource,
                color: status.failedSources.isEmpty
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  status.failedSources.isEmpty
                      ? AppStrings.noFailedSources
                      : AppStrings.labeledValue(
                          AppStrings.failedSources,
                          status.failedSources.join(
                            AppConstants.listDisplaySeparator,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: AppSizes.statusMetricIconSize),
      label: Text(AppStrings.labeledValue(label, value.toString())),
      backgroundColor: AppColors.neutralBackground,
      side: const BorderSide(color: AppColors.border),
    );
  }
}
