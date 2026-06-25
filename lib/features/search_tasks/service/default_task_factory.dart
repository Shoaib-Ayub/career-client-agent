import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';

class DefaultTaskFactory {
  const DefaultTaskFactory();

  List<SearchTask> create(UserProfile profile) {
    final createdAt = DateTime.now();
    final preferredLocation = profile.preferredCountries.isEmpty
        ? AppStrings.globalLocation
        : profile.preferredCountries.join(AppConstants.listDisplaySeparator);

    return [
      _task(
        id: AppConstants.defaultAiJobsTaskId,
        taskType: SearchTaskType.job,
        title: AppStrings.defaultAiJobsTitle,
        keywords: _parse(AppStrings.aiJobsKeywords),
        location: preferredLocation,
        level: AppStrings.fresherLevel,
        filters: _parse(AppStrings.aiJobsFilters),
        dailyLimit: AppConstants.defaultTaskDailyLimit,
        createdAt: createdAt,
      ),
      _task(
        id: AppConstants.defaultVisaJobsTaskId,
        taskType: SearchTaskType.job,
        title: AppStrings.defaultVisaJobsTitle,
        keywords: _parse(AppStrings.visaJobsKeywords),
        location: AppStrings.globalLocation,
        level: AppStrings.internationalLevel,
        filters: _parse(AppStrings.visaJobsFilters),
        dailyLimit: AppConstants.visaTaskDailyLimit,
        createdAt: createdAt,
      ),
      _task(
        id: AppConstants.defaultScholarshipsTaskId,
        taskType: SearchTaskType.scholarship,
        title: AppStrings.defaultScholarshipSearchTitle,
        keywords: _parse(AppStrings.msScholarshipKeywords),
        location: AppStrings.globalLocation,
        level: AppStrings.mastersLevel,
        filters: _parse(AppStrings.msScholarshipFilters),
        dailyLimit: AppConstants.defaultTaskDailyLimit,
        createdAt: createdAt,
      ),
      _task(
        id: AppConstants.defaultGovernmentJobsTaskId,
        taskType: SearchTaskType.governmentJob,
        title: AppStrings.defaultGovernmentSearchTitle,
        keywords: _parse(AppStrings.pakistanGovernmentKeywords),
        location: AppStrings.pakistanPunjabLocation,
        level: AppStrings.bachelorLevel,
        filters: _parse(AppStrings.pakistanGovernmentFilters),
        dailyLimit: AppConstants.governmentTaskDailyLimit,
        createdAt: createdAt,
      ),
      _task(
        id: AppConstants.defaultClientLeadsTaskId,
        taskType: SearchTaskType.clientLead,
        title: AppStrings.defaultClientSearchTitle,
        keywords: _parse(AppStrings.aiClientKeywords),
        location: AppStrings.remoteLocation,
        level: AppStrings.professionalLevel,
        filters: _parse(AppStrings.aiClientFilters),
        dailyLimit: AppConstants.clientLeadTaskDailyLimit,
        createdAt: createdAt,
      ),
    ];
  }

  SearchTask _task({
    required String id,
    required SearchTaskType taskType,
    required String title,
    required List<String> keywords,
    required String location,
    required String level,
    required List<String> filters,
    required int dailyLimit,
    required DateTime createdAt,
  }) {
    return SearchTask(
      id: id,
      taskType: taskType,
      title: title,
      keywords: keywords,
      location: location,
      level: level,
      filters: filters,
      dailyLimit: dailyLimit,
      isActive: true,
      createdAt: createdAt,
      lastRunAt: null,
    );
  }

  List<String> _parse(String value) {
    return value
        .split(AppConstants.listInputSeparator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
