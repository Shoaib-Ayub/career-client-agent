import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/network/remote_json_endpoints.dart';
import 'package:career_client_agent/features/government_jobs/data/dto/government_job_dto.dart';

class GovernmentJobsJsonDataSource {
  GovernmentJobsJsonDataSource(this._loader, {RemoteJsonDataSource? remote})
    : _remote = remote;

  final LatestJsonAssetLoader _loader;
  final RemoteJsonDataSource? _remote;

  Future<List<GovernmentJobDto>> loadBundled() async {
    final results = await _loader.loadLatest(
      AppAssets.governmentJobsDataDirectory,
    );
    return results.map(GovernmentJobDto.fromJson).toList();
  }

  Future<List<GovernmentJobDto>> loadRemote() async {
    final results = await _remote!.loadList(RemoteJsonEndpoints.governmentJobs);
    return results.map(GovernmentJobDto.fromJson).toList();
  }

  bool get hasRemote => _remote != null;
}
