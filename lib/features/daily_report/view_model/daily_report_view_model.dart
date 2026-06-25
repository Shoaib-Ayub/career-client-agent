import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/daily_report/model/daily_report_state.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/view_model/opportunity_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyReportViewModelProvider =
    AsyncNotifierProvider<DailyReportViewModel, DailyReportState>(
      DailyReportViewModel.new,
    );

class DailyReportViewModel extends AsyncNotifier<DailyReportState> {
  List<List<OpportunityResult>> _groups = const [];

  @override
  Future<DailyReportState> build() => _load(OpportunityFilter.today);

  void selectFilter(OpportunityFilter filter) {
    state = AsyncData(_stateFor(filter));
  }

  Future<bool> refresh() async {
    final current = state.value;
    if (current == null || current.isRefreshing) {
      return false;
    }

    state = AsyncData(current.copyWith(isRefreshing: true));
    try {
      state = AsyncData(await _load(current.selectedFilter, refresh: true));
      return true;
    } on Exception {
      state = AsyncData(current.copyWith(isRefreshing: false));
      return false;
    }
  }

  Future<DailyReportState> _load(
    OpportunityFilter filter, {
    bool refresh = false,
  }) async {
    final jobs = ref.read(jobsRepositoryProvider);
    final scholarships = ref.read(scholarshipsRepositoryProvider);
    final governmentJobs = ref.read(governmentJobsRepositoryProvider);
    final clientLeads = ref.read(clientLeadsRepositoryProvider);
    final results = await Future.wait([
      refresh ? jobs.fetchLatest() : jobs.getAll(),
      refresh ? scholarships.fetchLatest() : scholarships.getAll(),
      refresh ? governmentJobs.fetchLatest() : governmentJobs.getAll(),
      refresh ? clientLeads.fetchLatest() : clientLeads.getAll(),
    ]);
    _groups = results.cast<List<OpportunityResult>>();
    return _stateFor(filter);
  }

  DailyReportState _stateFor(OpportunityFilter filter) {
    final filterService = ref.read(opportunityFilterServiceProvider);
    int count(int index) => filterService.apply(_groups[index], filter).length;

    return DailyReportState(
      jobs: count(0),
      scholarships: count(1),
      governmentJobs: count(2),
      clientLeads: count(3),
      selectedFilter: filter,
    );
  }
}
