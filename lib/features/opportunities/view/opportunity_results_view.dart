import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/widgets/empty_state_widget.dart';
import 'package:career_client_agent/core/widgets/opportunity_card.dart';
import 'package:career_client_agent/core/widgets/refresh_button.dart';
import 'package:career_client_agent/core/widgets/section_header.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_list_state.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:flutter/material.dart';

class OpportunityResultsView<T extends OpportunityResult>
    extends StatelessWidget {
  const OpportunityResultsView({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.applicationType,
    this.isRefreshing = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final OpportunityListState<T> state;
  final ValueChanged<OpportunityFilter> onFilterChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final ApplicationType applicationType;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.opportunityCardMaxWidth,
        ),
        child: CustomScrollView(
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
                        Expanded(
                          child: SectionHeader(
                            title: title,
                            subtitle: subtitle,
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceMd),
                        RefreshButton(
                          onPressed: onRefresh,
                          isLoading: isRefreshing,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<OpportunityFilter>(
                        segments: OpportunityFilter.values
                            .map(
                              (filter) => ButtonSegment(
                                value: filter,
                                label: Text(filter.label),
                              ),
                            )
                            .toList(),
                        selected: {state.selectedFilter},
                        onSelectionChanged: (selection) {
                          onFilterChanged(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  title: AppStrings.noOpportunitiesTitle,
                  message: AppStrings.noOpportunitiesMessage,
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
                sliver: SliverList.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSizes.spaceMd),
                  itemBuilder: (context, index) {
                    return OpportunityCard(
                      opportunity: state.items[index],
                      applicationType: applicationType,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
