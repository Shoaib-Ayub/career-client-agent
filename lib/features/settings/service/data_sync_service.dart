import 'package:career_client_agent/core/config/app_config.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/storage/models/scholarship_model.dart';
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
    final downloads = await Future.wait<Object>([
      jobsRepository.downloadRemote(),
      scholarshipsRepository.downloadRemote(),
      governmentJobsRepository.downloadRemote(),
      clientLeadsRepository.downloadRemote(),
      ref.read(syncStatusRepositoryProvider).loadRemoteBackendStatus(),
    ]);
    final jobs = downloads[0] as List<JobModel>;
    final scholarships = downloads[1] as List<ScholarshipModel>;
    final governmentJobs = downloads[2] as List<GovernmentJobModel>;
    final clientLeads = downloads[3] as List<ClientLeadModel>;
    final backendStatus = downloads[4] as BackendRunStatus;
    await Future.wait([
      jobsRepository.saveDownloaded(jobs),
      scholarshipsRepository.saveDownloaded(scholarships),
      governmentJobsRepository.saveDownloaded(governmentJobs),
      clientLeadsRepository.saveDownloaded(clientLeads),
    ]);
    final results = <List<OpportunityResult>>[
      jobs,
      scholarships,
      governmentJobs,
      clientLeads,
    ];
    final allResults = results.expand((items) => items).toList();

    final updated = backendStatus.copyWith(
      lastSyncedAt: DateTime.now(),
      totalJobs: jobs.length,
      totalScholarships: scholarships.length,
      totalGovernmentJobs: governmentJobs.length,
      totalClientLeads: clientLeads.length,
      autoRefreshOnLaunch: current.autoRefreshOnLaunch,
      refreshIntervalHours: current.refreshIntervalHours,
      syncStatus: AppConstants.syncStatusSuccess,
      sourceUsed: AppConfig.apiEnabled
          ? AppConstants.dataSourceApi
          : AppConstants.dataSourceRemoteJson,
      recordsDownloaded: allResults.length,
      clearLastError: true,
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
          newJobs: jobs
              .where(
                (item) =>
                    previousSync == null || item.foundAt.isAfter(previousSync),
              )
              .toList(),
        );
    return updated;
  }

  Future<BackendRunStatus> recordFailure(Object error) async {
    final repository = ref.read(syncStatusRepositoryProvider);
    final current = await repository.getStatus();
    final failed = current.copyWith(
      syncStatus: AppConstants.syncStatusError,
      sourceUsed: AppConstants.dataSourceRemoteJson,
      recordsDownloaded: 0,
      lastError: error.toString(),
    );
    await repository.saveStatus(failed);
    return failed;
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
