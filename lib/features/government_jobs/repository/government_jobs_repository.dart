import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/features/government_jobs/data/data_source/government_jobs_json_data_source.dart';
import 'package:career_client_agent/features/government_jobs/data/mapper/government_job_mapper.dart';
import 'package:career_client_agent/features/government_jobs/service/government_jobs_service.dart';

class GovernmentJobsRepository extends HiveRepository<GovernmentJobModel> {
  GovernmentJobsRepository(
    LocalStorageService storage, {
    GovernmentJobsService? service,
    GovernmentJobsJsonDataSource? jsonDataSource,
  }) : _service = service,
       _jsonDataSource = jsonDataSource,
       super(
         boxName: AppConstants.governmentJobsBoxName,
         decoder: GovernmentJobModel.fromMap,
         storage: storage,
       );

  final GovernmentJobsService? _service;
  final GovernmentJobsJsonDataSource? _jsonDataSource;
  String lastSourceUsed = AppConstants.dataSourceUnknown;
  String? lastError;

  @override
  Future<List<GovernmentJobModel>> getAll() async {
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

  Future<List<GovernmentJobModel>> fetchLatest() async {
    final service = _service;
    final jsonDataSource = _jsonDataSource;
    lastError = null;
    try {
      if (service != null) {
        final models = (await service.fetchGovernmentJobs())
            .map(GovernmentJobMapper.toModel)
            .toList();
        await replaceAll(models);
        lastSourceUsed = AppConstants.dataSourceApi;
        return models;
      }
      if (jsonDataSource?.hasRemote ?? false) {
        final models = (await jsonDataSource!.loadRemote())
            .map(GovernmentJobMapper.toModel)
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
        .map(GovernmentJobMapper.toModel)
        .toList();
    await replaceAll(models);
    lastSourceUsed = AppConstants.dataSourceBundledAssets;
    return models;
  }
}
