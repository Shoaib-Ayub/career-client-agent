import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_list_state.dart';
import 'package:career_client_agent/features/opportunities/view_model/opportunity_providers.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final governmentJobsViewModelProvider =
    AsyncNotifierProvider<
      GovernmentJobsViewModel,
      OpportunityListState<GovernmentJobModel>
    >(GovernmentJobsViewModel.new);

class GovernmentJobsViewModel
    extends AsyncNotifier<OpportunityListState<GovernmentJobModel>> {
  List<GovernmentJobModel> _allItems = const [];

  @override
  Future<OpportunityListState<GovernmentJobModel>> build() async {
    _allItems = await _personalize(
      await ref.read(governmentJobsRepositoryProvider).getAll(),
    );
    return _stateFor(OpportunityFilter.latest);
  }

  void selectFilter(OpportunityFilter filter) {
    state = AsyncData(_stateFor(filter));
  }

  Future<bool> refresh() async {
    final current = state.value;
    if (current == null || current.isRefreshing) {
      return false;
    }

    final filter = current.selectedFilter;
    state = AsyncData(current.copyWith(isRefreshing: true));
    try {
      _allItems = await _personalize(
        await ref.read(governmentJobsRepositoryProvider).fetchLatest(),
      );
      state = AsyncData(_stateFor(filter));
      return true;
    } on Exception {
      state = AsyncData(current.copyWith(isRefreshing: false));
      return false;
    }
  }

  OpportunityListState<GovernmentJobModel> _stateFor(OpportunityFilter filter) {
    final items = ref
        .read(opportunityFilterServiceProvider)
        .apply(_allItems, filter);
    return OpportunityListState(items: items, selectedFilter: filter);
  }

  Future<List<GovernmentJobModel>> _personalize(
    List<GovernmentJobModel> items,
  ) async {
    final status = await ref.read(syncStatusRepositoryProvider).getStatus();
    return ref
        .read(personalizationServiceProvider)
        .personalize(
          items: items,
          profile: await ref.read(profileRepositoryProvider).getProfile(),
          tasks: await ref.read(searchTasksRepositoryProvider).getDomainTasks(),
          taskType: SearchTaskType.governmentJob,
          enabled: status.personalizedResultsEnabled,
          strictMatch: status.strictMatchEnabled,
        );
  }
}
