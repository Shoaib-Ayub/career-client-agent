import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/data/latest_json_asset_loader.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/network/remote_json_endpoints.dart';
import 'package:career_client_agent/features/client_leads/data/dto/client_lead_dto.dart';

class ClientLeadsJsonDataSource {
  ClientLeadsJsonDataSource(this._loader, {RemoteJsonDataSource? remote})
    : _remote = remote;

  final LatestJsonAssetLoader _loader;
  final RemoteJsonDataSource? _remote;

  Future<List<ClientLeadDto>> loadBundled() async {
    final results = await _loader.loadLatest(
      AppAssets.clientLeadsDataDirectory,
    );
    return results.map(ClientLeadDto.fromJson).toList();
  }

  Future<List<ClientLeadDto>> loadRemote() async {
    final results = await _remote!.loadList(RemoteJsonEndpoints.clientLeads);
    return results.map(ClientLeadDto.fromJson).toList();
  }

  bool get hasRemote => _remote != null;
}
