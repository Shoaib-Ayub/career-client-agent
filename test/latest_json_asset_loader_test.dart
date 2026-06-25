import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads only files from the latest backend generation', () async {
    final loader = LatestJsonAssetLoader();

    final jobs = await loader.loadLatest(AppAssets.jobsDataDirectory);
    final scholarships = await loader.loadLatest(
      AppAssets.scholarshipsDataDirectory,
    );
    final governmentJobs = await loader.loadLatest(
      AppAssets.governmentJobsDataDirectory,
    );
    final clientLeads = await loader.loadLatest(
      AppAssets.clientLeadsDataDirectory,
    );

    expect(jobs, isNotEmpty);
    expect(scholarships, isNotEmpty);
    expect(governmentJobs, isNotEmpty);
    expect(clientLeads, isNotEmpty);
  });
}
