import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/network/remote_json_endpoints.dart';
import 'package:career_client_agent/features/scholarships/data/dto/scholarship_dto.dart';

class ScholarshipsJsonDataSource {
  ScholarshipsJsonDataSource(this._loader, {RemoteJsonDataSource? remote})
    : _remote = remote;

  final LatestJsonAssetLoader _loader;
  final RemoteJsonDataSource? _remote;

  Future<List<ScholarshipDto>> loadBundled() async {
    final results = await _loader.loadLatest(
      AppAssets.scholarshipsDataDirectory,
    );
    return results.map(ScholarshipDto.fromJson).toList();
  }

  Future<List<ScholarshipDto>> loadRemote() async {
    final results = await _remote!.loadList(RemoteJsonEndpoints.scholarships);
    return results.map(ScholarshipDto.fromJson).toList();
  }

  bool get hasRemote => _remote != null;
}
