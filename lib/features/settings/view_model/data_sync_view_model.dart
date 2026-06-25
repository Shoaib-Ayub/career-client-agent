import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/client_leads/view_model/client_leads_view_model.dart';
import 'package:career_client_agent/features/daily_report/view_model/daily_report_view_model.dart';
import 'package:career_client_agent/features/dashboard/view_model/dashboard_view_model.dart';
import 'package:career_client_agent/features/government_jobs/view_model/government_jobs_view_model.dart';
import 'package:career_client_agent/features/jobs/view_model/jobs_view_model.dart';
import 'package:career_client_agent/features/scholarships/view_model/scholarships_view_model.dart';
import 'package:career_client_agent/features/settings/model/sync_state.dart';
import 'package:career_client_agent/features/settings/service/data_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataSyncViewModelProvider =
    AsyncNotifierProvider<DataSyncViewModel, SyncState>(DataSyncViewModel.new);

final dataSyncBootstrapProvider = FutureProvider<void>((ref) async {
  final status = await ref.read(syncStatusRepositoryProvider).getStatus();
  if (status.autoRefreshOnLaunch && status.isRefreshDue) {
    await ref.read(dataSyncServiceProvider).sync();
  }
});

class DataSyncViewModel extends AsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async {
    final status = await ref.read(syncStatusRepositoryProvider).getStatus();
    return SyncState(status: status);
  }

  Future<bool> syncNow() async {
    final current = state.value;
    if (current == null || current.isSyncing) {
      return false;
    }
    state = AsyncData(
      current.copyWith(
        status: current.status.copyWith(
          syncStatus: AppConstants.syncStatusSyncing,
        ),
        isSyncing: true,
        clearError: true,
      ),
    );
    try {
      final status = await ref.read(dataSyncServiceProvider).sync();
      state = AsyncData(SyncState(status: status));
      _invalidateOpportunityViews();
      return true;
    } on Exception catch (error) {
      final failedStatus = await ref
          .read(dataSyncServiceProvider)
          .recordFailure(error);
      state = AsyncData(
        current.copyWith(
          status: failedStatus,
          isSyncing: false,
          errorMessage: AppStrings.syncFailed,
        ),
      );
      return false;
    }
  }

  Future<void> setAutoRefresh(bool value) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final status = current.status.copyWith(autoRefreshOnLaunch: value);
    await ref.read(syncStatusRepositoryProvider).saveStatus(status);
    state = AsyncData(current.copyWith(status: status));
  }

  Future<void> setRefreshInterval(int hours) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final status = current.status.copyWith(refreshIntervalHours: hours);
    await ref.read(syncStatusRepositoryProvider).saveStatus(status);
    state = AsyncData(current.copyWith(status: status));
  }

  Future<bool> clearCache() async {
    try {
      await ref.read(dataSyncServiceProvider).clearOpportunityCache();
      _invalidateOpportunityViews();
      return true;
    } on Exception {
      return false;
    }
  }

  void _invalidateOpportunityViews() {
    ref.invalidate(jobsViewModelProvider);
    ref.invalidate(scholarshipsViewModelProvider);
    ref.invalidate(governmentJobsViewModelProvider);
    ref.invalidate(clientLeadsViewModelProvider);
    ref.invalidate(dashboardViewModelProvider);
    ref.invalidate(dailyReportViewModelProvider);
  }
}
