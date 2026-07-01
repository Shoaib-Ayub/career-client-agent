import 'package:career_client_agent/core/constants/app_constants.dart';

class BackendRunStatus {
  const BackendRunStatus({
    this.lastRunTime,
    this.lastSyncedAt,
    this.totalJobs = 0,
    this.totalScholarships = 0,
    this.totalGovernmentJobs = 0,
    this.totalClientLeads = 0,
    this.failedSources = const [],
    this.autoRefreshOnLaunch = false,
    this.personalizedResultsEnabled =
        AppConstants.defaultPersonalizedResultsEnabled,
    this.strictMatchEnabled = AppConstants.defaultStrictMatchEnabled,
    this.refreshIntervalHours = AppConstants.defaultRefreshIntervalHours,
    this.syncStatus = AppConstants.syncStatusSuccess,
    this.sourceUsed = AppConstants.dataSourceUnknown,
    this.recordsDownloaded = 0,
    this.lastError,
  });

  final DateTime? lastRunTime;
  final DateTime? lastSyncedAt;
  final int totalJobs;
  final int totalScholarships;
  final int totalGovernmentJobs;
  final int totalClientLeads;
  final List<String> failedSources;
  final bool autoRefreshOnLaunch;
  final bool personalizedResultsEnabled;
  final bool strictMatchEnabled;
  final int refreshIntervalHours;
  final String syncStatus;
  final String sourceUsed;
  final int recordsDownloaded;
  final String? lastError;

  bool get isRefreshDue {
    final syncedAt = lastSyncedAt;
    return syncedAt == null ||
        DateTime.now().difference(syncedAt).inHours >= refreshIntervalHours;
  }

  BackendRunStatus copyWith({
    DateTime? lastRunTime,
    DateTime? lastSyncedAt,
    int? totalJobs,
    int? totalScholarships,
    int? totalGovernmentJobs,
    int? totalClientLeads,
    List<String>? failedSources,
    bool? autoRefreshOnLaunch,
    bool? personalizedResultsEnabled,
    bool? strictMatchEnabled,
    int? refreshIntervalHours,
    String? syncStatus,
    String? sourceUsed,
    int? recordsDownloaded,
    String? lastError,
    bool clearLastError = false,
  }) {
    return BackendRunStatus(
      lastRunTime: lastRunTime ?? this.lastRunTime,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      totalJobs: totalJobs ?? this.totalJobs,
      totalScholarships: totalScholarships ?? this.totalScholarships,
      totalGovernmentJobs: totalGovernmentJobs ?? this.totalGovernmentJobs,
      totalClientLeads: totalClientLeads ?? this.totalClientLeads,
      failedSources: failedSources ?? this.failedSources,
      autoRefreshOnLaunch: autoRefreshOnLaunch ?? this.autoRefreshOnLaunch,
      personalizedResultsEnabled:
          personalizedResultsEnabled ?? this.personalizedResultsEnabled,
      strictMatchEnabled: strictMatchEnabled ?? this.strictMatchEnabled,
      refreshIntervalHours: refreshIntervalHours ?? this.refreshIntervalHours,
      syncStatus: syncStatus ?? this.syncStatus,
      sourceUsed: sourceUsed ?? this.sourceUsed,
      recordsDownloaded: recordsDownloaded ?? this.recordsDownloaded,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}
