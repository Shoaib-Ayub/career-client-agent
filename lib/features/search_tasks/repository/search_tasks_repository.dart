import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/hive_repository.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/search_task_model.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';

class SearchTasksRepository extends HiveRepository<SearchTaskModel> {
  SearchTasksRepository(LocalStorageService storage)
    : super(
        boxName: AppConstants.searchTasksBoxName,
        decoder: SearchTaskModel.fromMap,
        storage: storage,
      );

  Future<List<SearchTask>> getDomainTasks() async {
    return (await getAll()).map((model) => model.toDomain()).toList();
  }

  Future<SearchTask?> getDomainTask(String id) async {
    return (await getById(id))?.toDomain();
  }

  Future<void> saveDomainTask(SearchTask task) {
    return update(SearchTaskModel.fromDomain(task));
  }

  Future<void> saveDomainTasks(List<SearchTask> tasks) {
    return createAll(tasks.map(SearchTaskModel.fromDomain).toList());
  }

  Future<void> ensureDefaultTasks(List<SearchTask> defaults) async {
    final existing = await getAll();
    final existingIds = existing.map((task) => task.id).toSet();

    final hasNewDefaults = defaults.any(
      (task) => existingIds.contains(task.id),
    );
    if (!hasNewDefaults) {
      await _removeLegacyDefaults();
    }

    final refreshedIds = (await getAll()).map((task) => task.id).toSet();
    final missingDefaults = defaults
        .where((task) => !refreshedIds.contains(task.id))
        .toList();
    await saveDomainTasks(missingDefaults);
  }

  Future<void> _removeLegacyDefaults() async {
    for (final id in const [
      AppConstants.legacyJobTaskId,
      AppConstants.legacyScholarshipTaskId,
      AppConstants.legacyGovernmentTaskId,
      AppConstants.legacyClientTaskId,
    ]) {
      await delete(id);
    }
  }
}
