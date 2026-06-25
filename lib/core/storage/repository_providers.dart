import 'package:career_client_agent/core/config/app_config.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/network/service_providers.dart';
import 'package:career_client_agent/features/client_leads/data/data_source/client_leads_json_data_source.dart';
import 'package:career_client_agent/features/application_tracker/repository/application_tracker_repository.dart';
import 'package:career_client_agent/features/client_leads/repository/client_leads_repository.dart';
import 'package:career_client_agent/features/government_jobs/data/data_source/government_jobs_json_data_source.dart';
import 'package:career_client_agent/features/government_jobs/repository/government_jobs_repository.dart';
import 'package:career_client_agent/features/dashboard/service/dashboard_snapshot_service.dart';
import 'package:career_client_agent/features/jobs/data/data_source/jobs_json_data_source.dart';
import 'package:career_client_agent/features/jobs/repository/jobs_repository.dart';
import 'package:career_client_agent/features/profile/repository/profile_repository.dart';
import 'package:career_client_agent/features/profile_optimizer/repository/profile_optimizer_repository.dart';
import 'package:career_client_agent/features/scholarships/data/data_source/scholarships_json_data_source.dart';
import 'package:career_client_agent/features/scholarships/repository/scholarships_repository.dart';
import 'package:career_client_agent/features/search_tasks/repository/search_tasks_repository.dart';
import 'package:career_client_agent/features/settings/repository/notification_settings_repository.dart';
import 'package:career_client_agent/features/settings/data/backend_status_data_source.dart';
import 'package:career_client_agent/features/settings/repository/sync_status_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return const LocalStorageService();
});

final applicationTrackerRepositoryProvider =
    Provider<ApplicationTrackerRepository>((ref) {
      return ApplicationTrackerRepository(
        ref.watch(localStorageServiceProvider),
      );
    });

final dashboardSnapshotServiceProvider = Provider<DashboardSnapshotStore>((
  ref,
) {
  return DashboardSnapshotService(ref.watch(localStorageServiceProvider));
});

final latestJsonAssetLoaderProvider = Provider<LatestJsonAssetLoader>((ref) {
  return LatestJsonAssetLoader();
});

final remoteJsonDataSourceProvider = Provider<RemoteJsonDataSource?>((ref) {
  if (!AppConfig.remoteJsonEnabled) {
    return null;
  }
  return RemoteJsonDataSource(baseUrl: AppConfig.githubRawBaseUrl);
});

final jobsJsonDataSourceProvider = Provider<JobsJsonDataSource>((ref) {
  return JobsJsonDataSource(
    ref.watch(latestJsonAssetLoaderProvider),
    remote: ref.watch(remoteJsonDataSourceProvider),
  );
});

final scholarshipsJsonDataSourceProvider = Provider<ScholarshipsJsonDataSource>(
  (ref) {
    return ScholarshipsJsonDataSource(
      ref.watch(latestJsonAssetLoaderProvider),
      remote: ref.watch(remoteJsonDataSourceProvider),
    );
  },
);

final governmentJobsJsonDataSourceProvider =
    Provider<GovernmentJobsJsonDataSource>((ref) {
      return GovernmentJobsJsonDataSource(
        ref.watch(latestJsonAssetLoaderProvider),
        remote: ref.watch(remoteJsonDataSourceProvider),
      );
    });

final clientLeadsJsonDataSourceProvider = Provider<ClientLeadsJsonDataSource>((
  ref,
) {
  return ClientLeadsJsonDataSource(
    ref.watch(latestJsonAssetLoaderProvider),
    remote: ref.watch(remoteJsonDataSourceProvider),
  );
});

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(
    ref.watch(localStorageServiceProvider),
    service: AppConfig.apiEnabled ? ref.watch(jobsServiceProvider) : null,
    jsonDataSource: ref.watch(jobsJsonDataSourceProvider),
  );
});

final scholarshipsRepositoryProvider = Provider<ScholarshipsRepository>((ref) {
  return ScholarshipsRepository(
    ref.watch(localStorageServiceProvider),
    service: AppConfig.apiEnabled
        ? ref.watch(scholarshipsServiceProvider)
        : null,
    jsonDataSource: ref.watch(scholarshipsJsonDataSourceProvider),
  );
});

final governmentJobsRepositoryProvider = Provider<GovernmentJobsRepository>((
  ref,
) {
  return GovernmentJobsRepository(
    ref.watch(localStorageServiceProvider),
    service: AppConfig.apiEnabled
        ? ref.watch(governmentJobsServiceProvider)
        : null,
    jsonDataSource: ref.watch(governmentJobsJsonDataSourceProvider),
  );
});

final clientLeadsRepositoryProvider = Provider<ClientLeadsRepository>((ref) {
  return ClientLeadsRepository(
    ref.watch(localStorageServiceProvider),
    service: AppConfig.apiEnabled
        ? ref.watch(clientLeadsServiceProvider)
        : null,
    jsonDataSource: ref.watch(clientLeadsJsonDataSourceProvider),
  );
});

final searchTasksRepositoryProvider = Provider<SearchTasksRepository>((ref) {
  return SearchTasksRepository(ref.watch(localStorageServiceProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(localStorageServiceProvider));
});

final profileOptimizerRepositoryProvider = Provider<ProfileOptimizerRepository>(
  (ref) {
    return ProfileOptimizerRepository(ref.watch(localStorageServiceProvider));
  },
);

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
      return NotificationSettingsRepository(
        ref.watch(localStorageServiceProvider),
      );
    });

final backendStatusDataSourceProvider = Provider<BackendStatusDataSource>((
  ref,
) {
  return BackendStatusDataSource(
    remote: ref.watch(remoteJsonDataSourceProvider),
  );
});

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  return SyncStatusRepository(
    ref.watch(localStorageServiceProvider),
    ref.watch(backendStatusDataSourceProvider),
  );
});
