import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/foundation.dart';

enum SearchTaskType {
  job,
  scholarship,
  governmentJob,
  clientLead;

  String get label => switch (this) {
    SearchTaskType.job => AppStrings.jobSearchType,
    SearchTaskType.scholarship => AppStrings.scholarshipSearchType,
    SearchTaskType.governmentJob => AppStrings.governmentJobSearchType,
    SearchTaskType.clientLead => AppStrings.clientLeadSearchType,
  };
}

@immutable
class SearchTask {
  const SearchTask({
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

  final String id;
  final SearchTaskType taskType;
  final String title;
  final List<String> keywords;
  final String location;
  final String level;
  final List<String> filters;
  final int dailyLimit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastRunAt;

  SearchTask copyWith({
    String? id,
    SearchTaskType? taskType,
    String? title,
    List<String>? keywords,
    String? location,
    String? level,
    List<String>? filters,
    int? dailyLimit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastRunAt,
  }) {
    return SearchTask(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      title: title ?? this.title,
      keywords: keywords ?? this.keywords,
      location: location ?? this.location,
      level: level ?? this.level,
      filters: filters ?? this.filters,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}
