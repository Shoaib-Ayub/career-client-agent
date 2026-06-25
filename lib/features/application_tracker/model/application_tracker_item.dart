import 'package:career_client_agent/core/constants/app_strings.dart';

enum ApplicationType {
  job,
  scholarship,
  govtJob,
  clientLead;

  String get label => switch (this) {
    ApplicationType.job => AppStrings.trackerJobType,
    ApplicationType.scholarship => AppStrings.trackerScholarshipType,
    ApplicationType.govtJob => AppStrings.trackerGovernmentJobType,
    ApplicationType.clientLead => AppStrings.trackerClientLeadType,
  };
}

enum ApplicationStatus {
  saved,
  preparing,
  applied,
  interview,
  rejected,
  selected;

  String get label => switch (this) {
    ApplicationStatus.saved => AppStrings.savedStatus,
    ApplicationStatus.preparing => AppStrings.preparingStatus,
    ApplicationStatus.applied => AppStrings.appliedStatus,
    ApplicationStatus.interview => AppStrings.interviewStatus,
    ApplicationStatus.rejected => AppStrings.rejectedStatus,
    ApplicationStatus.selected => AppStrings.selectedStatus,
  };
}

class ApplicationTrackerItem {
  const ApplicationTrackerItem({
    required this.id,
    required this.opportunityId,
    required this.title,
    required this.organization,
    required this.type,
    required this.sourceLink,
    required this.status,
    required this.deadline,
    required this.notes,
    required this.requiredSkills,
    required this.cvSuggestions,
    required this.savedAt,
    this.appliedDate,
    this.followUpDate,
  });

  final String id;
  final String opportunityId;
  final String title;
  final String organization;
  final ApplicationType type;
  final String sourceLink;
  final ApplicationStatus status;
  final DateTime? appliedDate;
  final DateTime deadline;
  final String notes;
  final DateTime? followUpDate;
  final List<String> requiredSkills;
  final List<String> cvSuggestions;
  final DateTime savedAt;

  ApplicationTrackerItem copyWith({
    ApplicationStatus? status,
    DateTime? appliedDate,
    bool clearAppliedDate = false,
    String? notes,
    DateTime? followUpDate,
    bool clearFollowUpDate = false,
  }) {
    return ApplicationTrackerItem(
      id: id,
      opportunityId: opportunityId,
      title: title,
      organization: organization,
      type: type,
      sourceLink: sourceLink,
      status: status ?? this.status,
      appliedDate: clearAppliedDate ? null : appliedDate ?? this.appliedDate,
      deadline: deadline,
      notes: notes ?? this.notes,
      followUpDate: clearFollowUpDate
          ? null
          : followUpDate ?? this.followUpDate,
      requiredSkills: requiredSkills,
      cvSuggestions: cvSuggestions,
      savedAt: savedAt,
    );
  }
}
