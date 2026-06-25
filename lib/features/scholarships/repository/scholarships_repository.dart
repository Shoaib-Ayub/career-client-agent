import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/scholarship_model.dart';
import 'package:career_client_agent/features/scholarships/data/data_source/scholarships_json_data_source.dart';
import 'package:career_client_agent/features/scholarships/data/mapper/scholarship_mapper.dart';
import 'package:career_client_agent/features/scholarships/service/scholarships_service.dart';

class ScholarshipsRepository extends HiveRepository<ScholarshipModel> {
  ScholarshipsRepository(
    LocalStorageService storage, {
    ScholarshipsService? service,
    ScholarshipsJsonDataSource? jsonDataSource,
  }) : _service = service,
       _jsonDataSource = jsonDataSource,
       super(
         boxName: AppConstants.scholarshipsBoxName,
         decoder: ScholarshipModel.fromMap,
         storage: storage,
       );

  final ScholarshipsService? _service;
  final ScholarshipsJsonDataSource? _jsonDataSource;
  String lastSourceUsed = AppConstants.dataSourceUnknown;
  String? lastError;

  @override
  Future<List<ScholarshipModel>> getAll() async {
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

  Future<List<ScholarshipModel>> fetchLatest() async {
    final service = _service;
    final jsonDataSource = _jsonDataSource;
    lastError = null;
    try {
      if (service != null) {
        final models = (await service.fetchScholarships())
            .map(ScholarshipMapper.toModel)
            .toList();
        await replaceAll(models);
        lastSourceUsed = AppConstants.dataSourceApi;
        return models;
      }
      if (jsonDataSource?.hasRemote ?? false) {
        final models = (await jsonDataSource!.loadRemote())
            .map(ScholarshipMapper.toModel)
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
        .map(ScholarshipMapper.toModel)
        .toList();
    await replaceAll(models);
    lastSourceUsed = AppConstants.dataSourceBundledAssets;
    return models;
  }

  Future<List<ScholarshipModel>> downloadRemote() async {
    final service = _service;
    if (service != null) {
      lastSourceUsed = AppConstants.dataSourceApi;
      return (await service.fetchScholarships())
          .map(ScholarshipMapper.toModel)
          .toList();
    }
    final dataSource = _jsonDataSource;
    if (dataSource == null || !dataSource.hasRemote) {
      throw StateError('Remote scholarships source is not configured.');
    }
    lastSourceUsed = AppConstants.dataSourceRemoteJson;
    return (await dataSource.loadRemote())
        .map(ScholarshipMapper.toModel)
        .toList();
  }

  Future<void> saveDownloaded(List<ScholarshipModel> models) =>
      replaceAll(models);
}
