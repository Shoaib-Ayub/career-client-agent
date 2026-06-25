import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/network/remote_json_endpoints.dart';
import 'package:career_client_agent/features/jobs/data/dto/job_dto.dart';

class JobsJsonDataSource {
  JobsJsonDataSource(this._loader, {RemoteJsonDataSource? remote})
    : _remote = remote;

  final LatestJsonAssetLoader _loader;
  final RemoteJsonDataSource? _remote;

  Future<List<JobDto>> loadBundled() async {
    final results = await _loader.loadLatest(AppAssets.jobsDataDirectory);
    return results.map(JobDto.fromJson).toList();
  }

  Future<List<JobDto>> loadRemote() async {
    final results = await _remote!.loadList(RemoteJsonEndpoints.jobs);
    return results.map(JobDto.fromJson).toList();
  }

  bool get hasRemote => _remote != null;
}
