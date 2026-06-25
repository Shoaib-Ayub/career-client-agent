import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/refresh_feedback.dart';
import 'package:career_client_agent/core/utils/app_date_formatter.dart';
import 'package:career_client_agent/core/widgets/empty_state_widget.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/refresh_button.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/core/widgets/summary_card.dart';
import 'package:career_client_agent/features/dashboard/model/dashboard_state.dart';
import 'package:career_client_agent/features/dashboard/view_model/dashboard_view_model.dart';
import 'package:career_client_agent/features/settings/view_model/data_sync_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dashboardViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(dashboardViewModelProvider),
          ),
          data: (state) => state.isEmpty
              ? const EmptyStateWidget(
                  title: AppStrings.noOpportunitiesTitle,
                  message: AppStrings.noOpportunitiesMessage,
                )
              : _DashboardSuccess(state: state),
        );
  }
}

class _DashboardSuccess extends ConsumerWidget {
  const _DashboardSuccess({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref
        .read(dashboardViewModelProvider.notifier)
        .summaries(state);
    final dataSync = ref.watch(dataSyncViewModelProvider).value;
    final syncStatus = dataSync?.status;
    final lastSyncTime = syncStatus?.lastSyncedAt ?? state.lastSyncTime;
    final dataSource = syncStatus?.sourceUsed ?? state.dataSource;
    final recordsDownloaded =
        syncStatus?.recordsDownloaded ?? state.recordsDownloaded;
    final lastSyncStatus = syncStatus?.syncStatus ?? state.lastSyncStatus;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnCount =
                constraints.maxWidth >= AppSizes.dashboardWideGridBreakpoint
                ? AppConstants.wideGridColumnCount
                : constraints.maxWidth >= AppSizes.dashboardGridBreakpoint
                ? AppConstants.expandedGridColumnCount
                : AppConstants.compactGridColumnCount;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spaceLg,
                    AppSizes.spaceLg,
                    AppSizes.spaceLg,
                    AppSizes.spaceMd,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SectionHeader(
                            title: AppStrings.dashboardDataTitle,
                            subtitle:
                                '${AppStrings.dashboardDataSubtitle}\n'
                                '${AppStrings.lastUpdatedValue(AppDateFormatter.dateTime(state.lastUpdatedAt))}\n'
                                '${AppStrings.lastSyncedValue(lastSyncTime == null ? AppStrings.neverSynced : AppDateFormatter.dateTime(lastSyncTime))}\n'
                                '${AppStrings.dataSourceValue(dataSource)}\n'
                                '${AppStrings.recordsDownloadedValue(recordsDownloaded)} · '
                                '${AppStrings.lastSyncStatusValue(lastSyncStatus)}',
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceMd),
                        RefreshButton(
                          isLoading: dataSync?.isSyncing ?? false,
                          onPressed: () => RefreshFeedback.show(
                            context,
                            ref
                                .read(dataSyncViewModelProvider.notifier)
                                .syncNow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spaceLg,
                    AppSizes.spaceMd,
                    AppSizes.spaceLg,
                    AppSizes.spaceLg,
                  ),
                  sliver: SliverGrid.builder(
                    itemCount: summaries.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      mainAxisSpacing: AppSizes.spaceMd,
                      crossAxisSpacing: AppSizes.spaceMd,
                      mainAxisExtent: AppSizes.dashboardCardMinHeight,
                    ),
                    itemBuilder: (context, index) {
                      final summary = summaries[index];
                      return SummaryCard(
                        title: summary.title,
                        value: summary.value,
                        icon: summary.icon,
                        accentColor: summary.accentColor,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
