import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/refresh_feedback.dart';
import 'package:career_client_agent/core/widgets/empty_state_widget.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/core/widgets/refresh_button.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/core/widgets/summary_card.dart';
import 'package:career_client_agent/features/daily_report/model/daily_report_state.dart';
import 'package:career_client_agent/features/daily_report/view_model/daily_report_view_model.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  static const _filters = [
    OpportunityFilter.today,
    OpportunityFilter.last24Hours,
    OpportunityFilter.last7Days,
    OpportunityFilter.all,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dailyReportViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(dailyReportViewModelProvider),
          ),
          data: (state) => _DailyReportSuccess(state: state),
        );
  }
}

class _DailyReportSuccess extends ConsumerWidget {
  const _DailyReportSuccess({required this.state});

  final DailyReportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = [
      (AppStrings.todayJobs, state.jobs, AppIcons.jobs, AppColors.jobsAccent),
      (
        AppStrings.todayScholarships,
        state.scholarships,
        AppIcons.scholarships,
        AppColors.scholarshipsAccent,
      ),
      (
        AppStrings.todayGovernmentJobs,
        state.governmentJobs,
        AppIcons.governmentJobs,
        AppColors.governmentAccent,
      ),
      (
        AppStrings.todayClientLeads,
        state.clientLeads,
        AppIcons.clientLeads,
        AppColors.clientsAccent,
      ),
      (
        AppStrings.totalOpportunitiesFoundToday,
        state.total,
        AppIcons.dailyReport,
        AppColors.reportAccent,
      ),
    ];

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
                  padding: const EdgeInsets.all(AppSizes.spaceLg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: SectionHeader(
                                title: AppStrings.dailyReportTitle,
                                subtitle: AppStrings.dailyReportDescription,
                              ),
                            ),
                            const SizedBox(width: AppSizes.spaceMd),
                            RefreshButton(
                              isLoading: state.isRefreshing,
                              onPressed: () => RefreshFeedback.show(
                                context,
                                ref
                                    .read(dailyReportViewModelProvider.notifier)
                                    .refresh,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spaceMd),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<OpportunityFilter>(
                            segments: DailyReportScreen._filters
                                .map(
                                  (filter) => ButtonSegment(
                                    value: filter,
                                    label: Text(filter.label),
                                  ),
                                )
                                .toList(),
                            selected: {state.selectedFilter},
                            onSelectionChanged: (selection) {
                              ref
                                  .read(dailyReportViewModelProvider.notifier)
                                  .selectFilter(selection.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      title: AppStrings.noDailyReportTitle,
                      message: AppStrings.noDailyReportMessage,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.spaceLg,
                      AppSizes.zero,
                      AppSizes.spaceLg,
                      AppSizes.spaceLg,
                    ),
                    sliver: SliverGrid.builder(
                      itemCount: cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        mainAxisSpacing: AppSizes.spaceMd,
                        crossAxisSpacing: AppSizes.spaceMd,
                        mainAxisExtent: AppSizes.dashboardCardMinHeight,
                      ),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return SummaryCard(
                          title: card.$1,
                          value: AppStrings.countValue(card.$2),
                          icon: card.$3,
                          accentColor: card.$4,
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
