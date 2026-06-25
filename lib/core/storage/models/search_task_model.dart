import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';

class SearchTaskModel implements LocalModel {
  const SearchTaskModel({
    required this.id,
    required this.taskType,
    required this.title,
    required this.keywords,
    required this.location,
    required this.level,
    required this.filters,
    required this.dailyLimit,
    required this.isActive,
    required this.createdAt,
    required this.lastRunAt,
  });

  @override
  final String id;
  final String taskType;
  final String title;
  final List<String> keywords;
  final String location;
  final String level;
  final List<String> filters;
  final int dailyLimit;
  final bool isActive;
  final String createdAt;
  final String? lastRunAt;

  factory SearchTaskModel.fromDomain(SearchTask task) => SearchTaskModel(
    id: task.id,
    taskType: task.taskType.name,
    title: task.title,
    keywords: task.keywords,
    location: task.location,
    level: task.level,
    filters: task.filters,
    dailyLimit: task.dailyLimit,
    isActive: task.isActive,
    createdAt: task.createdAt.toIso8601String(),
    lastRunAt: task.lastRunAt?.toIso8601String(),
  );

  factory SearchTaskModel.fromMap(Map<dynamic, dynamic> map) {
    return SearchTaskModel(
      id: map['id'] as String,
      taskType: (map['taskType'] ?? map['type']) as String,
      title: map['title'] as String,
      keywords: List<String>.from(map['keywords'] as List),
      location:
          (map['location'] ?? map['country'] ?? AppStrings.globalLocation)
              as String,
      level: (map['level'] ?? AppStrings.professionalLevel) as String,
      filters: List<String>.from(map['filters'] as List),
      dailyLimit: (map['dailyLimit'] ?? map['dailyResultLimit']) as int,
      isActive: map['isActive'] as bool,
      createdAt:
          (map['createdAt'] ?? DateTime.now().toIso8601String()) as String,
      lastRunAt: map['lastRunAt'] as String?,
    );
  }

  SearchTask toDomain() => SearchTask(
    id: id,
    taskType: SearchTaskType.values.byName(taskType),
    title: title,
    keywords: keywords,
    location: location,
    level: level,
    filters: filters,
    dailyLimit: dailyLimit,
    isActive: isActive,
    createdAt: DateTime.parse(createdAt),
    lastRunAt: lastRunAt == null ? null : DateTime.parse(lastRunAt!),
  );

  @override
  Map<String, Object> toMap() => {
    'id': id,
    'taskType': taskType,
    'title': title,
    'keywords': keywords,
    'location': location,
    'level': level,
    'filters': filters,
    'dailyLimit': dailyLimit,
    'isActive': isActive,
    'createdAt': createdAt,
    'lastRunAt': ?lastRunAt,
  };
}
