import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/refresh_feedback.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/features/opportunities/view/opportunity_results_view.dart';
import 'package:career_client_agent/features/scholarships/view_model/scholarships_view_model.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScholarshipsScreen extends ConsumerWidget {
  const ScholarshipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(scholarshipsViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(scholarshipsViewModelProvider),
          ),
          data: (state) => OpportunityResultsView(
            title: AppStrings.scholarshipsTitle,
            applicationType: ApplicationType.scholarship,
            subtitle: AppStrings.scholarshipsResultsSubtitle,
            state: state,
            onFilterChanged: ref
                .read(scholarshipsViewModelProvider.notifier)
                .selectFilter,
            isRefreshing: state.isRefreshing,
            onRefresh: () => RefreshFeedback.show(
              context,
              ref.read(scholarshipsViewModelProvider.notifier).refresh,
            ),
          ),
        );
  }
}
