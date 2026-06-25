import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/settings/model/backend_run_status.dart';
import 'package:career_client_agent/features/settings/service/notification_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  return DataSyncService(ref);
});

class DataSyncService {
  const DataSyncService(this.ref);

  final Ref ref;

  Future<BackendRunStatus> sync() async {
    final current = await ref.read(syncStatusRepositoryProvider).getStatus();
    final jobsRepository = ref.read(jobsRepositoryProvider);
    final scholarshipsRepository = ref.read(scholarshipsRepositoryProvider);
    final governmentJobsRepository = ref.read(governmentJobsRepositoryProvider);
    final clientLeadsRepository = ref.read(clientLeadsRepositoryProvider);
    final results = await Future.wait([
      jobsRepository.fetchLatest(),
      scholarshipsRepository.fetchLatest(),
      governmentJobsRepository.fetchLatest(),
      clientLeadsRepository.fetchLatest(),
    ]);
    final allResults = results
        .expand((items) => items)
        .cast<OpportunityResult>()
        .toList();

    BackendRunStatus backendStatus;
    try {
      backendStatus = await ref
          .read(syncStatusRepositoryProvider)
          .loadBackendStatus();
    } on Exception {
      backendStatus = BackendRunStatus(
        lastRunTime: allResults.isEmpty
            ? current.lastRunTime
            : allResults
                  .map((item) => item.foundAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b),
      );
    }

    final updated = backendStatus.copyWith(
      lastSyncedAt: DateTime.now(),
      totalJobs: results[0].length,
      totalScholarships: results[1].length,
      totalGovernmentJobs: results[2].length,
      totalClientLeads: results[3].length,
      autoRefreshOnLaunch: current.autoRefreshOnLaunch,
      refreshIntervalHours: current.refreshIntervalHours,
      syncStatus: _syncStatus([
        jobsRepository.lastSourceUsed,
        scholarshipsRepository.lastSourceUsed,
        governmentJobsRepository.lastSourceUsed,
        clientLeadsRepository.lastSourceUsed,
      ]),
      sourceUsed: _sourceUsed([
        jobsRepository.lastSourceUsed,
        scholarshipsRepository.lastSourceUsed,
        governmentJobsRepository.lastSourceUsed,
        clientLeadsRepository.lastSourceUsed,
      ]),
      recordsDownloaded: _recordsDownloaded(results, [
        jobsRepository.lastSourceUsed,
        scholarshipsRepository.lastSourceUsed,
        governmentJobsRepository.lastSourceUsed,
        clientLeadsRepository.lastSourceUsed,
      ]),
      lastError: _lastError([
        jobsRepository.lastError,
        scholarshipsRepository.lastError,
        governmentJobsRepository.lastError,
        clientLeadsRepository.lastError,
      ]),
      clearLastError: [
        jobsRepository.lastError,
        scholarshipsRepository.lastError,
        governmentJobsRepository.lastError,
        clientLeadsRepository.lastError,
      ].every((error) => error == null),
    );
    await ref.read(syncStatusRepositoryProvider).saveStatus(updated);
    final previousSync = current.lastSyncedAt;
    final newItems = allResults.where(
      (item) => previousSync == null || item.foundAt.isAfter(previousSync),
    );
    await ref
        .read(notificationCoordinatorProvider)
        .notifyNewOpportunities(
          newOpportunityCount: newItems.length,
          newJobs: results[0]
              .cast<OpportunityResult>()
              .where(
                (item) =>
                    previousSync == null || item.foundAt.isAfter(previousSync),
              )
              .toList(),
        );
    return updated;
  }

  String _sourceUsed(List<String> sources) {
    final unique = sources.toSet();
    return unique.length == 1 ? unique.single : AppConstants.dataSourceMixed;
  }

  String _syncStatus(List<String> sources) {
    return sources.every(
          (source) =>
              source == AppConstants.dataSourceRemoteJson ||
              source == AppConstants.dataSourceApi,
        )
        ? AppConstants.syncStatusSuccess
        : AppConstants.syncStatusFallback;
  }

  int _recordsDownloaded(List<List<Object>> results, List<String> sources) {
    var downloaded = 0;
    for (var index = 0; index < results.length; index++) {
      if (sources[index] == AppConstants.dataSourceRemoteJson ||
          sources[index] == AppConstants.dataSourceApi) {
        downloaded += results[index].length;
      }
    }
    return downloaded;
  }

  String? _lastError(List<String?> errors) {
    final messages = errors.whereType<String>().toSet();
    return messages.isEmpty ? null : messages.join('\n');
  }

  Future<void> clearOpportunityCache() async {
    final storage = ref.read(localStorageServiceProvider);
    await Future.wait([
      storage.clear(AppConstants.jobsBoxName),
      storage.clear(AppConstants.scholarshipsBoxName),
      storage.clear(AppConstants.governmentJobsBoxName),
      storage.clear(AppConstants.clientLeadsBoxName),
      storage.clear(AppConstants.dashboardMetadataBoxName),
    ]);
  }
}
