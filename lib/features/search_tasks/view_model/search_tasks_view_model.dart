import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/profile/view_model/profile_view_model.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';
import 'package:career_client_agent/features/search_tasks/repository/search_tasks_repository.dart';
import 'package:career_client_agent/features/search_tasks/service/default_task_factory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final defaultTaskFactoryProvider = Provider<DefaultTaskFactory>((ref) {
  return const DefaultTaskFactory();
});

final searchTasksViewModelProvider =
    AsyncNotifierProvider<SearchTasksViewModel, List<SearchTask>>(
      SearchTasksViewModel.new,
    );

class SearchTasksViewModel extends AsyncNotifier<List<SearchTask>> {
  SearchTasksRepository get _repository =>
      ref.read(searchTasksRepositoryProvider);

  @override
  Future<List<SearchTask>> build() async {
    final profile = ref.read(profileViewModelProvider);
    final defaults = ref.read(defaultTaskFactoryProvider).create(profile);
    await _repository.ensureDefaultTasks(defaults);
    return _repository.getDomainTasks();
  }

  Future<void> saveTask(SearchTask task) async {
    await _repository.saveDomainTask(task);
    state = AsyncData(await _repository.getDomainTasks());
  }

  Future<void> deleteTask(String id) async {
    await _repository.delete(id);
    state = AsyncData(await _repository.getDomainTasks());
  }

  Future<void> toggleStatus(SearchTask task) {
    return saveTask(task.copyWith(isActive: !task.isActive));
  }

  SearchTask? findById(String id) {
    for (final task in state.value ?? const <SearchTask>[]) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  SearchTask createTask({
    required SearchTaskType type,
    required String title,
    required String keywords,
    required String location,
    required String level,
    required String filters,
    required String dailyLimit,
    required bool isActive,
    String? id,
    DateTime? createdAt,
    DateTime? lastRunAt,
  }) {
    return SearchTask(
      id:
          id ??
          '${AppConstants.taskIdPrefix}-${DateTime.now().microsecondsSinceEpoch}',
      taskType: type,
      title: title.trim(),
      keywords: _parseList(keywords),
      location: location.trim(),
      level: level.trim(),
      filters: _parseList(filters),
      dailyLimit:
          int.tryParse(dailyLimit) ?? AppConstants.defaultTaskDailyLimit,
      isActive: isActive,
      createdAt: createdAt ?? DateTime.now(),
      lastRunAt: lastRunAt,
    );
  }

  List<String> _parseList(String value) {
    return value
        .split(AppConstants.listInputSeparator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
