import 'dart:io';

import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/features/dashboard/view_model/dashboard_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

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

  test('dashboard loads the latest backend JSON totals', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loader = LatestJsonAssetLoader();
    final expected = await Future.wait([
      loader.loadLatest(AppAssets.jobsDataDirectory),
      loader.loadLatest(AppAssets.scholarshipsDataDirectory),
      loader.loadLatest(AppAssets.governmentJobsDataDirectory),
      loader.loadLatest(AppAssets.clientLeadsDataDirectory),
    ]);

    final dashboard = await container.read(dashboardViewModelProvider.future);

    expect(dashboard.jobs, expected[0].length);
    expect(dashboard.scholarships, expected[1].length);
    expect(dashboard.governmentJobs, expected[2].length);
    expect(dashboard.clientLeads, expected[3].length);
    expect(dashboard.newSinceLastRun, greaterThan(0));
    expect(
      dashboard.newSinceLastRun,
      lessThanOrEqualTo(
        dashboard.jobs +
            dashboard.scholarships +
            dashboard.governmentJobs +
            dashboard.clientLeads,
      ),
    );
    expect(dashboard.lastUpdatedAt, isNotNull);

    container.invalidate(dashboardViewModelProvider);
    final refreshed = await container.read(dashboardViewModelProvider.future);
    expect(refreshed.newSinceLastRun, 0);
  });
}
