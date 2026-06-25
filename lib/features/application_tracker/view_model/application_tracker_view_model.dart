import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/application_tracker/model/apply_assistant_result.dart';
import 'package:career_client_agent/features/application_tracker/service/apply_assistant_service.dart';
import 'package:career_client_agent/features/profile/view_model/profile_view_model.dart';
import 'package:career_client_agent/features/settings/service/notification_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final applyAssistantServiceProvider = Provider<ApplyAssistantService>((ref) {
  return const ApplyAssistantService();
});

final applicationTrackerViewModelProvider =
    AsyncNotifierProvider<
      ApplicationTrackerViewModel,
      List<ApplicationTrackerItem>
    >(ApplicationTrackerViewModel.new);

class ApplicationTrackerViewModel
    extends AsyncNotifier<List<ApplicationTrackerItem>> {
  @override
  Future<List<ApplicationTrackerItem>> build() {
    return ref.read(applicationTrackerRepositoryProvider).getItems();
  }

  Future<bool> saveOpportunity({
    required OpportunityResult opportunity,
    required ApplicationType type,
  }) async {
    final repository = ref.read(applicationTrackerRepositoryProvider);
    if (await repository.containsOpportunity(opportunity.id)) {
      return false;
    }

    final item = ApplicationTrackerItem(
      id:
          '${AppConstants.applicationTrackerBoxName}-'
          '${DateTime.now().microsecondsSinceEpoch}',
      opportunityId: opportunity.id,
      title: opportunity.title,
      organization: opportunity.organization,
      type: type,
      sourceLink: opportunity.sourceLink,
      status: ApplicationStatus.saved,
      deadline: opportunity.deadline,
      notes: AppStrings.emptyValue,
      requiredSkills: opportunity.requiredSkills,
      cvSuggestions: opportunity.cvSuggestions,
      savedAt: DateTime.now(),
    );
    await repository.saveItem(item);
    state = AsyncData(await repository.getItems());
    await ref.read(notificationCoordinatorProvider).synchronize();
    return true;
  }

  Future<void> updateItem(ApplicationTrackerItem item) async {
    final repository = ref.read(applicationTrackerRepositoryProvider);
    await repository.saveItem(item);
    state = AsyncData(await repository.getItems());
    await ref.read(notificationCoordinatorProvider).synchronize();
  }

  Future<void> updateStatus(
    ApplicationTrackerItem item,
    ApplicationStatus status,
  ) {
    return updateItem(
      item.copyWith(
        status: status,
        appliedDate: status == ApplicationStatus.applied
            ? item.appliedDate ?? DateTime.now()
            : item.appliedDate,
      ),
    );
  }

  Future<void> markApplied(ApplicationTrackerItem item) {
    return updateStatus(item, ApplicationStatus.applied);
  }

  Future<void> updateNotes(ApplicationTrackerItem item, String notes) {
    return updateItem(item.copyWith(notes: notes.trim()));
  }

  Future<void> updateFollowUp(ApplicationTrackerItem item, DateTime date) {
    return updateItem(item.copyWith(followUpDate: date));
  }

  ApplyAssistantResult assistantFor(ApplicationTrackerItem item) {
    return ref
        .read(applyAssistantServiceProvider)
        .generate(item: item, profile: ref.read(profileViewModelProvider));
  }
}
