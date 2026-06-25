import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/features/settings/view/widgets/backend_run_status_card.dart';
import 'package:career_client_agent/features/settings/view_model/data_sync_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataRefreshSettingsScreen extends ConsumerWidget {
  const DataRefreshSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.dataRefreshSettingsOption)),
      body: ref
          .watch(dataSyncViewModelProvider)
          .when(
            loading: LoadingWidget.new,
            error: (error, stackTrace) => ErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(dataSyncViewModelProvider),
            ),
            data: (state) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.settingsMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.spaceLg),
                  children: [
                    ProfileCard(
                      title: AppStrings.manualSyncTitle,
                      subtitle: AppStrings.manualSyncDescription,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                AppIcons.sync,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSizes.spaceSm),
                              Expanded(
                                child: Text(
                                  AppStrings.lastSyncedValue(
                                    state.status.lastSyncedAt == null
                                        ? AppStrings.neverSynced
                                        : AppDateFormatter.dateTime(
                                            state.status.lastSyncedAt!,
                                          ),
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: state.isSyncing
                                    ? null
                                    : () => _sync(context, ref),
                                icon: state.isSyncing
                                    ? const SizedBox.square(
                                        dimension: AppSizes.refreshProgressSize,
                                        child: CircularProgressIndicator(
                                          strokeWidth: AppSizes
                                              .refreshProgressStrokeWidth,
                                        ),
                                      )
                                    : const Icon(AppIcons.sync),
                                label: Text(
                                  state.isSyncing
                                      ? AppStrings.syncingData
                                      : AppStrings.syncNow,
                                ),
                              ),
                            ],
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: AppSizes.spaceMd),
                            Text(
                              state.errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.rejected),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    ProfileCard(
                      title: AppStrings.dataRefreshSettingsOption,
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(AppIcons.dataRefresh),
                            title: const Text(AppStrings.autoRefreshOnLaunch),
                            subtitle: const Text(
                              AppStrings.autoRefreshOnLaunchDescription,
                            ),
                            value: state.status.autoRefreshOnLaunch,
                            onChanged: ref
                                .read(dataSyncViewModelProvider.notifier)
                                .setAutoRefresh,
                          ),
                          const Divider(),
                          DropdownButtonFormField<int>(
                            initialValue: state.status.refreshIntervalHours,
                            decoration: const InputDecoration(
                              labelText: AppStrings.refreshInterval,
                              prefixIcon: Icon(AppIcons.updated),
                              border: OutlineInputBorder(),
                            ),
                            items: AppConstants.refreshIntervalOptions
                                .map(
                                  (hours) => DropdownMenuItem(
                                    value: hours,
                                    child: Text(
                                      AppStrings.refreshIntervalHours(hours),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(dataSyncViewModelProvider.notifier)
                                    .setRefreshInterval(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    BackendRunStatusCard(status: state.status),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final succeeded = await ref
        .read(dataSyncViewModelProvider.notifier)
        .syncNow();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded ? AppStrings.syncSuccessful : AppStrings.syncFailed,
          ),
        ),
      );
  }
}
