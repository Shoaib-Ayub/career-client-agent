import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/dashboard/model/dashboard_state.dart';
import 'package:career_client_agent/features/dashboard/model/summary_item.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardViewModelProvider =
    AsyncNotifierProvider<DashboardViewModel, DashboardState>(
      DashboardViewModel.new,
    );

class DashboardViewModel extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() => _load();

  Future<bool> refresh() async {
    final current = state.value;
    if (current == null || current.isRefreshing) {
      return false;
    }

    state = AsyncData(current.copyWith(isRefreshing: true));
    try {
      state = AsyncData(await _load(refresh: true));
      return true;
    } on Exception {
      state = AsyncData(current.copyWith(isRefreshing: false));
      return false;
    }
  }

  Future<DashboardState> _load({bool refresh = false}) async {
    final jobsRepository = ref.read(jobsRepositoryProvider);
    final scholarshipsRepository = ref.read(scholarshipsRepositoryProvider);
    final governmentJobsRepository = ref.read(governmentJobsRepositoryProvider);
    final clientLeadsRepository = ref.read(clientLeadsRepositoryProvider);
    final results = await Future.wait([
      refresh ? jobsRepository.fetchLatest() : jobsRepository.getAll(),
      refresh
          ? scholarshipsRepository.fetchLatest()
          : scholarshipsRepository.getAll(),
      refresh
          ? governmentJobsRepository.fetchLatest()
          : governmentJobsRepository.getAll(),
      refresh
          ? clientLeadsRepository.fetchLatest()
          : clientLeadsRepository.getAll(),
    ]);
    final groups = results.cast<List<OpportunityResult>>();
    final allItems = <({String category, OpportunityResult item})>[
      for (final item in groups[0])
        (category: AppConstants.jobsBoxName, item: item),
      for (final item in groups[1])
        (category: AppConstants.scholarshipsBoxName, item: item),
      for (final item in groups[2])
        (category: AppConstants.governmentJobsBoxName, item: item),
      for (final item in groups[3])
        (category: AppConstants.clientLeadsBoxName, item: item),
    ];
    final currentIds = {
      for (final entry in allItems) '${entry.category}:${entry.item.id}',
    };
    final snapshotService = ref.read(dashboardSnapshotServiceProvider);
    final previous = await snapshotService.read();
    final newSinceLastRun = currentIds
        .difference(previous.opportunityIds)
        .length;
    final lastUpdatedAt = allItems.isEmpty
        ? previous.updatedAt ?? DateTime.now()
        : allItems
              .map((entry) => entry.item.foundAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    await snapshotService.save(
      opportunityIds: currentIds,
      updatedAt: lastUpdatedAt,
    );
    return DashboardState(
      jobs: groups[0].length,
      scholarships: groups[1].length,
      governmentJobs: groups[2].length,
      clientLeads: groups[3].length,
      todayTotal: allItems
          .where(
            (entry) => entry.item.freshnessStatus == OpportunityFreshness.today,
          )
          .length,
      newSinceLastRun: newSinceLastRun,
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  List<SummaryItem> summaries(DashboardState state) => [
    SummaryItem(
      title: AppStrings.totalJobs,
      value: AppStrings.countValue(state.jobs),
      icon: AppIcons.jobs,
      accentColor: AppColors.jobsAccent,
    ),
    SummaryItem(
      title: AppStrings.totalScholarships,
      value: AppStrings.countValue(state.scholarships),
      icon: AppIcons.scholarships,
      accentColor: AppColors.scholarshipsAccent,
    ),
    SummaryItem(
      title: AppStrings.totalGovernmentJobs,
      value: AppStrings.countValue(state.governmentJobs),
      icon: AppIcons.governmentJobs,
      accentColor: AppColors.governmentAccent,
    ),
    SummaryItem(
      title: AppStrings.totalClientLeads,
      value: AppStrings.countValue(state.clientLeads),
      icon: AppIcons.clientLeads,
      accentColor: AppColors.clientsAccent,
    ),
    SummaryItem(
      title: AppStrings.todayOpportunities,
      value: AppStrings.countValue(state.todayTotal),
      icon: AppIcons.dailyReport,
      accentColor: AppColors.reportAccent,
    ),
    SummaryItem(
      title: AppStrings.newSinceLastRun,
      value: AppStrings.countValue(state.newSinceLastRun),
      icon: AppIcons.newOpportunities,
      accentColor: AppColors.relocationAccent,
    ),
  ];
}
