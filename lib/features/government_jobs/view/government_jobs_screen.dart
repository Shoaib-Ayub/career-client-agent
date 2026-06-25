import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/refresh_feedback.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/features/government_jobs/view_model/government_jobs_view_model.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/opportunities/view/opportunity_results_view.dart';
import 'package:career_client_agent/features/settings/view_model/data_sync_view_model.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GovernmentJobsScreen extends ConsumerWidget {
  const GovernmentJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(dataSyncViewModelProvider).value;
    return ref
        .watch(governmentJobsViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(governmentJobsViewModelProvider),
          ),
          data: (state) => OpportunityResultsView(
            title: AppStrings.governmentJobsTitle,
            applicationType: ApplicationType.govtJob,
            subtitle: AppStrings.governmentJobsResultsSubtitle,
            state: state,
            onFilterChanged: ref
                .read(governmentJobsViewModelProvider.notifier)
                .selectFilter,
            isRefreshing: syncState?.isSyncing ?? false,
            onRefresh: () => RefreshFeedback.show(
              context,
              ref.read(dataSyncViewModelProvider.notifier).syncNow,
            ),
          ),
        );
  }
}
