import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/features/client_leads/data/data_source/client_leads_json_data_source.dart';
import 'package:career_client_agent/features/client_leads/data/mapper/client_lead_mapper.dart';
import 'package:career_client_agent/features/client_leads/service/client_leads_service.dart';

class ClientLeadsRepository extends HiveRepository<ClientLeadModel> {
  ClientLeadsRepository(
    LocalStorageService storage, {
    ClientLeadsService? service,
    ClientLeadsJsonDataSource? jsonDataSource,
  }) : _service = service,
       _jsonDataSource = jsonDataSource,
       super(
         boxName: AppConstants.clientLeadsBoxName,
         decoder: ClientLeadModel.fromMap,
         storage: storage,
       );

  final ClientLeadsService? _service;
  final ClientLeadsJsonDataSource? _jsonDataSource;
  String lastSourceUsed = AppConstants.dataSourceUnknown;
  String? lastError;

  @override
  Future<List<ClientLeadModel>> getAll() async {
    try {
      return fetchLatest();
    } on Exception {
      final cached = await super.getAll();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<ClientLeadModel>> fetchLatest() async {
    final service = _service;
    final jsonDataSource = _jsonDataSource;
    lastError = null;
    try {
      if (service != null) {
        final models = (await service.fetchClientLeads())
            .map(ClientLeadMapper.toModel)
            .toList();
        await replaceAll(models);
        lastSourceUsed = AppConstants.dataSourceApi;
        return models;
      }
      if (jsonDataSource?.hasRemote ?? false) {
        final models = (await jsonDataSource!.loadRemote())
            .map(ClientLeadMapper.toModel)
            .toList();
        await replaceAll(models);
        lastSourceUsed = AppConstants.dataSourceRemoteJson;
        return models;
      }
    } on Exception catch (error) {
      lastError = error.toString();
    }
    final cached = await super.getAll();
    if (cached.isNotEmpty) {
      lastSourceUsed = AppConstants.dataSourceHiveCache;
      return cached;
    }
    if (jsonDataSource == null) {
      if (lastError != null) {
        throw Exception(lastError);
      }
      return cached;
    }
    final models = (await jsonDataSource.loadBundled())
        .map(ClientLeadMapper.toModel)
        .toList();
    await replaceAll(models);
    lastSourceUsed = AppConstants.dataSourceBundledAssets;
    return models;
  }
}
