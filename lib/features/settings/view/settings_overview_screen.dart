import 'package:career_client_agent/app/routes/app_routes.dart';
import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/profile_card.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/features/settings/view/widgets/backend_run_status_card.dart';
import 'package:career_client_agent/features/settings/view_model/data_sync_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsOverviewScreen extends ConsumerWidget {
  const SettingsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(dataSyncViewModelProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.settingsMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          children: [
            const SectionHeader(
              title: AppStrings.settingsOverviewTitle,
              subtitle: AppStrings.settingsOverviewSubtitle,
            ),
            const SizedBox(height: AppSizes.spaceLg),
            _SettingsOptions(ref: ref),
            const SizedBox(height: AppSizes.spaceMd),
            syncState.when(
              loading: LoadingWidget.new,
              error: (error, stackTrace) => ErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(dataSyncViewModelProvider),
              ),
              data: (state) => Column(
                children: [
                  ProfileCard(
                    title: AppStrings.manualSyncTitle,
                    subtitle: AppStrings.manualSyncDescription,
                    child: Row(
                      children: [
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
                                    strokeWidth:
                                        AppSizes.refreshProgressStrokeWidth,
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
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  BackendRunStatusCard(status: state.status),
                ],
              ),
            ),
          ],
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

class _SettingsOptions extends StatelessWidget {
  const _SettingsOptions({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Column(
        children: [
          _SettingsTile(
            icon: AppIcons.profile,
            title: AppStrings.updateProfileOption,
            subtitle: AppStrings.updateProfileOptionDescription,
            onTap: () => context.pushNamed(AppRoutes.profileName),
          ),
          _SettingsTile(
            icon: AppIcons.searchTasks,
            title: AppStrings.manageSearchTasksOption,
            subtitle: AppStrings.manageSearchTasksOptionDescription,
            onTap: () => context.pushNamed(AppRoutes.searchTasksName),
          ),
          _SettingsTile(
            icon: AppIcons.notifications,
            title: AppStrings.notificationSettingsOption,
            subtitle: AppStrings.notificationSettingsOptionDescription,
            onTap: () => context.pushNamed(AppRoutes.notificationSettingsName),
          ),
          _SettingsTile(
            icon: AppIcons.dataRefresh,
            title: AppStrings.dataRefreshSettingsOption,
            subtitle: AppStrings.dataRefreshSettingsOptionDescription,
            onTap: () => context.pushNamed(AppRoutes.dataRefreshSettingsName),
          ),
          _SettingsTile(
            icon: AppIcons.clearCache,
            title: AppStrings.clearLocalCacheOption,
            subtitle: AppStrings.clearLocalCacheOptionDescription,
            onTap: () => _confirmClearCache(context),
          ),
          _SettingsTile(
            icon: AppIcons.about,
            title: AppStrings.appVersionAboutOption,
            subtitle: AppStrings.appVersionLabel,
            showDivider: false,
            onTap: () => showAboutDialog(
              context: context,
              applicationName: AppStrings.appName,
              applicationVersion: AppStrings.appVersion,
              applicationLegalese: AppStrings.aboutLegalese,
              children: const [
                SizedBox(height: AppSizes.spaceMd),
                Text(AppStrings.appVersionAboutDescription),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.clearCacheTitle),
        content: const Text(AppStrings.clearCacheConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.clearCacheAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final succeeded = await ref
        .read(dataSyncViewModelProvider.notifier)
        .clearCache();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded ? AppStrings.cacheCleared : AppStrings.cacheClearFailed,
          ),
        ),
      );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            size: AppSizes.settingsOptionIconSize,
            color: AppColors.primary,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(AppIcons.chevron),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: AppSizes.borderWidth),
      ],
    );
  }
}
