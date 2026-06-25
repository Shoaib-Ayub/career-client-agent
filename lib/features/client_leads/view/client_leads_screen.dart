import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/utils/refresh_feedback.dart';
import 'package:career_client_agent/core/widgets/error_widget.dart';
import 'package:career_client_agent/core/widgets/loading_widget.dart';
import 'package:career_client_agent/features/client_leads/view_model/client_leads_view_model.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/opportunities/view/opportunity_results_view.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClientLeadsScreen extends ConsumerWidget {
  const ClientLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(clientLeadsViewModelProvider)
        .when(
          loading: LoadingWidget.new,
          error: (error, stackTrace) => ErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(clientLeadsViewModelProvider),
          ),
          data: (state) => OpportunityResultsView(
            title: AppStrings.clientLeadsTitle,
            applicationType: ApplicationType.clientLead,
            subtitle: AppStrings.clientLeadsResultsSubtitle,
            state: state,
            onFilterChanged: ref
                .read(clientLeadsViewModelProvider.notifier)
                .selectFilter,
            isRefreshing: state.isRefreshing,
            onRefresh: () => RefreshFeedback.show(
              context,
              ref.read(clientLeadsViewModelProvider.notifier).refresh,
            ),
          ),
        );
  }
}
