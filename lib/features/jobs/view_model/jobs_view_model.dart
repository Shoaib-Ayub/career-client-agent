import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/jobs/data/mock_jobs.dart';
import 'package:career_client_agent/features/jobs/model/job.dart';
import 'package:career_client_agent/features/jobs/model/match_result.dart';
import 'package:career_client_agent/features/jobs/service/match_engine_service.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_list_state.dart';
import 'package:career_client_agent/features/opportunities/view_model/opportunity_providers.dart';
import 'package:career_client_agent/features/profile/view_model/profile_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jobsViewModelProvider =
    AsyncNotifierProvider<JobsViewModel, OpportunityListState<JobModel>>(
      JobsViewModel.new,
    );

class JobsViewModel extends AsyncNotifier<OpportunityListState<JobModel>> {
  List<JobModel> _allItems = const [];

  @override
  Future<OpportunityListState<JobModel>> build() async {
    _allItems = await ref.read(jobsRepositoryProvider).getAll();
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
      _allItems = await ref.read(jobsRepositoryProvider).fetchLatest();
      state = AsyncData(_stateFor(filter));
      return true;
    } on Exception {
      state = AsyncData(current.copyWith(isRefreshing: false));
      return false;
    }
  }

  OpportunityListState<JobModel> _stateFor(OpportunityFilter filter) {
    final items = ref
        .read(opportunityFilterServiceProvider)
        .apply(_allItems, filter);
    return OpportunityListState(items: items, selectedFilter: filter);
  }
}

final matchEngineServiceProvider = Provider<MatchEngineService>((ref) {
  return const MatchEngineService();
});

final mockJobsProvider = Provider<List<Job>>((ref) {
  return MockJobs.all;
});

final featuredJobProvider = Provider<Job>((ref) {
  return ref.watch(mockJobsProvider).first;
});

final featuredMatchProvider = Provider<MatchResult>((ref) {
  final engine = ref.watch(matchEngineServiceProvider);
  final profile = ref.watch(profileViewModelProvider);
  final job = ref.watch(featuredJobProvider);

  return engine.calculate(profile: profile, job: job);
});
