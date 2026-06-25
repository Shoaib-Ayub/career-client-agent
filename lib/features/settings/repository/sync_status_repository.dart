import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/sync_status_model.dart';
import 'package:career_client_agent/features/settings/data/backend_status_data_source.dart';
import 'package:career_client_agent/features/settings/model/backend_run_status.dart';

class SyncStatusRepository extends HiveRepository<SyncStatusModel> {
  SyncStatusRepository(LocalStorageService storage, this._dataSource)
    : super(
        boxName: AppConstants.syncStatusBoxName,
        decoder: SyncStatusModel.fromMap,
        storage: storage,
      );

  final BackendStatusDataSource _dataSource;

  Future<BackendRunStatus> getStatus() async {
    final saved = await getById(AppConstants.syncStatusRecordId);
    if (saved != null) {
      return saved.toDomain();
    }
    try {
      final status = await _dataSource.load();
      await saveStatus(status);
      return status;
    } on Exception {
      return const BackendRunStatus();
    }
  }

  Future<BackendRunStatus> loadBackendStatus() => _dataSource.load();

  Future<void> saveStatus(BackendRunStatus status) {
    return update(SyncStatusModel.fromDomain(status));
  }
}
