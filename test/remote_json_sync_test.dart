import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/client_leads/data/data_source/client_leads_json_data_source.dart';
import 'package:career_client_agent/features/client_leads/repository/client_leads_repository.dart';
import 'package:career_client_agent/features/government_jobs/data/data_source/government_jobs_json_data_source.dart';
import 'package:career_client_agent/features/government_jobs/repository/government_jobs_repository.dart';
import 'package:career_client_agent/features/jobs/data/data_source/jobs_json_data_source.dart';
import 'package:career_client_agent/features/jobs/repository/jobs_repository.dart';
import 'package:career_client_agent/features/scholarships/data/data_source/scholarships_json_data_source.dart';
import 'package:career_client_agent/features/scholarships/repository/scholarships_repository.dart';
import 'package:career_client_agent/features/settings/data/backend_status_data_source.dart';
import 'package:career_client_agent/features/settings/repository/sync_status_repository.dart';
import 'package:career_client_agent/features/settings/service/data_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp();
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('remote JSON data source fetches a valid list', () async {
    final source = RemoteJsonDataSource(
      baseUrl: 'https://raw.example/data',
      client: MockClient(
        (request) async => http.Response('[$_remoteJobJson]', 200),
      ),
    );

    final records = await source.loadList('jobs/latest.json');

    expect(records, hasLength(1));
    expect(records.single['title'], 'Remote Flutter Job');
  });

  test('repository caches records downloaded from remote JSON', () async {
    final repository = JobsRepository(
      const LocalStorageService(),
      jsonDataSource: JobsJsonDataSource(
        LatestJsonAssetLoader(),
        remote: RemoteJsonDataSource(
          baseUrl: 'https://raw.example/data',
          client: MockClient(
            (request) async => http.Response('[$_remoteJobJson]', 200),
          ),
        ),
      ),
    );

    final results = await repository.fetchLatest();
    final cached = await const LocalStorageService().getAll(
      AppConstants.jobsBoxName,
    );

    expect(results, hasLength(1));
    expect(cached, hasLength(1));
    expect(repository.lastSourceUsed, AppConstants.dataSourceRemoteJson);
  });

  test('repository falls back to Hive when remote JSON fails', () async {
    final repository = JobsRepository(
      const LocalStorageService(),
      jsonDataSource: JobsJsonDataSource(
        LatestJsonAssetLoader(),
        remote: RemoteJsonDataSource(
          baseUrl: 'https://raw.example/data',
          client: MockClient(
            (request) async => http.Response('rate limited', 429),
          ),
        ),
      ),
    );
    await repository.create(_cachedJob);

    final results = await repository.fetchLatest();

    expect(results, hasLength(1));
    expect(results.single.title, _cachedJob.title);
    expect(repository.lastSourceUsed, AppConstants.dataSourceHiveCache);
    expect(repository.lastError, isNotNull);
  });

  test(
    'manual sync downloads all remote categories and saves metadata',
    () async {
      final remote = RemoteJsonDataSource(
        baseUrl: 'https://raw.example/data',
        client: MockClient((request) async {
          if (request.url.path.endsWith('run_status.json')) {
            return http.Response(_runStatusJson, 200);
          }
          return http.Response('[$_remoteJobJson]', 200);
        }),
      );
      const storage = LocalStorageService();
      final container = ProviderContainer(
        overrides: [
          jobsRepositoryProvider.overrideWithValue(
            JobsRepository(
              storage,
              jsonDataSource: JobsJsonDataSource(
                LatestJsonAssetLoader(),
                remote: remote,
              ),
            ),
          ),
          scholarshipsRepositoryProvider.overrideWithValue(
            ScholarshipsRepository(
              storage,
              jsonDataSource: ScholarshipsJsonDataSource(
                LatestJsonAssetLoader(),
                remote: remote,
              ),
            ),
          ),
          governmentJobsRepositoryProvider.overrideWithValue(
            GovernmentJobsRepository(
              storage,
              jsonDataSource: GovernmentJobsJsonDataSource(
                LatestJsonAssetLoader(),
                remote: remote,
              ),
            ),
          ),
          clientLeadsRepositoryProvider.overrideWithValue(
            ClientLeadsRepository(
              storage,
              jsonDataSource: ClientLeadsJsonDataSource(
                LatestJsonAssetLoader(),
                remote: remote,
              ),
            ),
          ),
          syncStatusRepositoryProvider.overrideWithValue(
            SyncStatusRepository(
              storage,
              BackendStatusDataSource(remote: remote),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(dataSyncServiceProvider).sync();

      expect(status.syncStatus, AppConstants.syncStatusSuccess);
      expect(status.sourceUsed, AppConstants.dataSourceRemoteJson);
      expect(status.recordsDownloaded, 4);
      expect(status.lastSyncedAt, isNotNull);
      expect(status.lastError, isNull);
    },
  );
}

const _remoteJobJson = '''
{
  "title": "Remote Flutter Job",
  "organization": "Remote Company",
  "location": "Remote",
  "source_link": "https://example.com/jobs/flutter",
  "posted_date": "2026-06-24",
  "deadline": "2026-07-24",
  "skills": ["Flutter"],
  "match_score": 90,
  "fresher_friendly": true,
  "visa_sponsorship": false,
  "training_provided": true,
  "why_match": ["Flutter"],
  "cv_suggestions": [],
  "found_at": "2026-06-24T08:00:00Z",
  "source_name": "GitHub Raw Test",
  "freshness_status": "today"
}
''';

const _runStatusJson = '''
{
  "last_run_time": "2026-06-24T08:00:00Z",
  "total_jobs": 1,
  "total_scholarships": 1,
  "total_government_jobs": 1,
  "total_client_leads": 1,
  "failed_sources": []
}
''';

final _cachedJob = JobModel(
  id: 'cached-job',
  title: 'Cached Flutter Job',
  organization: 'Cached Company',
  location: 'Pakistan',
  sourceLink: 'https://example.com/cached',
  postedDate: DateTime(2026, 6, 23),
  deadline: DateTime(2026, 7, 23),
  requiredSkills: const ['Flutter'],
  matchScore: 80,
  fresherFriendly: true,
  visaSponsorship: false,
  trainingProvided: false,
  whyMatch: const ['Flutter'],
  cvSuggestions: const [],
  requiredEducation: 'Bachelor',
  minimumExperienceYears: 0,
  jobType: 'Full-time',
);
