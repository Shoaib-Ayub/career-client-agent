import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/features/settings/model/backend_run_status.dart';

class SyncStatusModel implements LocalModel {
  const SyncStatusModel({
    required this.lastRunTime,
    required this.lastSyncedAt,
    required this.totalJobs,
    required this.totalScholarships,
    required this.totalGovernmentJobs,
    required this.totalClientLeads,
    required this.failedSources,
    required this.autoRefreshOnLaunch,
    required this.refreshIntervalHours,
    required this.syncStatus,
    required this.sourceUsed,
    required this.recordsDownloaded,
    required this.lastError,
  });

  @override
  String get id => AppConstants.syncStatusRecordId;

  final String? lastRunTime;
  final String? lastSyncedAt;
  final int totalJobs;
  final int totalScholarships;
  final int totalGovernmentJobs;
  final int totalClientLeads;
  final List<String> failedSources;
  final bool autoRefreshOnLaunch;
  final int refreshIntervalHours;
  final String syncStatus;
  final String sourceUsed;
  final int recordsDownloaded;
  final String? lastError;

  factory SyncStatusModel.fromDomain(BackendRunStatus status) {
    return SyncStatusModel(
      lastRunTime: status.lastRunTime?.toIso8601String(),
      lastSyncedAt: status.lastSyncedAt?.toIso8601String(),
      totalJobs: status.totalJobs,
      totalScholarships: status.totalScholarships,
      totalGovernmentJobs: status.totalGovernmentJobs,
      totalClientLeads: status.totalClientLeads,
      failedSources: status.failedSources,
      autoRefreshOnLaunch: status.autoRefreshOnLaunch,
      refreshIntervalHours: status.refreshIntervalHours,
      syncStatus: status.syncStatus,
      sourceUsed: status.sourceUsed,
      recordsDownloaded: status.recordsDownloaded,
      lastError: status.lastError,
    );
  }

  factory SyncStatusModel.fromMap(Map<dynamic, dynamic> map) {
    return SyncStatusModel(
      lastRunTime: map['lastRunTime'] as String?,
      lastSyncedAt: map['lastSyncedAt'] as String?,
      totalJobs: (map['totalJobs'] ?? 0) as int,
      totalScholarships: (map['totalScholarships'] ?? 0) as int,
      totalGovernmentJobs: (map['totalGovernmentJobs'] ?? 0) as int,
      totalClientLeads: (map['totalClientLeads'] ?? 0) as int,
      failedSources: List<String>.from(
        map['failedSources'] as List? ?? const [],
      ),
      autoRefreshOnLaunch: (map['autoRefreshOnLaunch'] ?? false) as bool,
      refreshIntervalHours:
          (map['refreshIntervalHours'] ??
                  AppConstants.defaultRefreshIntervalHours)
              as int,
      syncStatus:
          (map['syncStatus'] ?? AppConstants.syncStatusSuccess) as String,
      sourceUsed:
          (map['sourceUsed'] ?? AppConstants.dataSourceUnknown) as String,
      recordsDownloaded: (map['recordsDownloaded'] ?? 0) as int,
      lastError: map['lastError'] as String?,
    );
  }

  BackendRunStatus toDomain() => BackendRunStatus(
    lastRunTime: lastRunTime == null ? null : DateTime.parse(lastRunTime!),
    lastSyncedAt: lastSyncedAt == null ? null : DateTime.parse(lastSyncedAt!),
    totalJobs: totalJobs,
    totalScholarships: totalScholarships,
    totalGovernmentJobs: totalGovernmentJobs,
    totalClientLeads: totalClientLeads,
    failedSources: failedSources,
    autoRefreshOnLaunch: autoRefreshOnLaunch,
    refreshIntervalHours: refreshIntervalHours,
    syncStatus: syncStatus,
    sourceUsed: sourceUsed,
    recordsDownloaded: recordsDownloaded,
    lastError: lastError,
  );

  @override
  Map<String, Object> toMap() => {
    'lastRunTime': ?lastRunTime,
    'lastSyncedAt': ?lastSyncedAt,
    'totalJobs': totalJobs,
    'totalScholarships': totalScholarships,
    'totalGovernmentJobs': totalGovernmentJobs,
    'totalClientLeads': totalClientLeads,
    'failedSources': failedSources,
    'autoRefreshOnLaunch': autoRefreshOnLaunch,
    'refreshIntervalHours': refreshIntervalHours,
    'syncStatus': syncStatus,
    'sourceUsed': sourceUsed,
    'recordsDownloaded': recordsDownloaded,
    'lastError': ?lastError,
  };
}
