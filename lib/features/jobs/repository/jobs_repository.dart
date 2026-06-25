import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/features/jobs/data/data_source/jobs_json_data_source.dart';
import 'package:career_client_agent/features/jobs/data/mapper/job_mapper.dart';
import 'package:career_client_agent/features/jobs/service/jobs_service.dart';

class JobsRepository extends HiveRepository<JobModel> {
  JobsRepository(
    LocalStorageService storage, {
    JobsService? service,
    JobsJsonDataSource? jsonDataSource,
  }) : _service = service,
       _jsonDataSource = jsonDataSource,
       super(
         boxName: AppConstants.jobsBoxName,
         decoder: JobModel.fromMap,
         storage: storage,
       );

  final JobsService? _service;
  final JobsJsonDataSource? _jsonDataSource;
  String lastSourceUsed = AppConstants.dataSourceUnknown;
  String? lastError;

  @override
  Future<List<JobModel>> getAll() async {
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

  Future<List<JobModel>> fetchLatest() async {
    final service = _service;
    final jsonDataSource = _jsonDataSource;
    lastError = null;
    try {
      if (service != null) {
        final models = (await service.fetchJobs())
            .map(JobMapper.toModel)
            .toList();
        await replaceAll(models);
        lastSourceUsed = AppConstants.dataSourceApi;
        return models;
      }
      if (jsonDataSource?.hasRemote ?? false) {
        final models = (await jsonDataSource!.loadRemote())
            .map(JobMapper.toModel)
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
        .map(JobMapper.toModel)
        .toList();
    await replaceAll(models);
    lastSourceUsed = AppConstants.dataSourceBundledAssets;
    return models;
  }

  Future<List<JobModel>> downloadRemote() async {
    final service = _service;
    if (service != null) {
      lastSourceUsed = AppConstants.dataSourceApi;
      return (await service.fetchJobs()).map(JobMapper.toModel).toList();
    }
    final dataSource = _jsonDataSource;
    if (dataSource == null || !dataSource.hasRemote) {
      throw StateError('Remote jobs source is not configured.');
    }
    lastSourceUsed = AppConstants.dataSourceRemoteJson;
    return (await dataSource.loadRemote()).map(JobMapper.toModel).toList();
  }

  Future<void> saveDownloaded(List<JobModel> models) => replaceAll(models);
}
