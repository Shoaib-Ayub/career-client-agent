import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';

class ApplicationTrackerModel implements LocalModel {
  const ApplicationTrackerModel({
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

  @override
  final String id;
  final String opportunityId;
  final String title;
  final String organization;
  final String type;
  final String sourceLink;
  final String status;
  final String? appliedDate;
  final String deadline;
  final String notes;
  final String? followUpDate;
  final List<String> requiredSkills;
  final List<String> cvSuggestions;
  final String savedAt;

  factory ApplicationTrackerModel.fromDomain(ApplicationTrackerItem item) {
    return ApplicationTrackerModel(
      id: item.id,
      opportunityId: item.opportunityId,
      title: item.title,
      organization: item.organization,
      type: item.type.name,
      sourceLink: item.sourceLink,
      status: item.status.name,
      appliedDate: item.appliedDate?.toIso8601String(),
      deadline: item.deadline.toIso8601String(),
      notes: item.notes,
      followUpDate: item.followUpDate?.toIso8601String(),
      requiredSkills: item.requiredSkills,
      cvSuggestions: item.cvSuggestions,
      savedAt: item.savedAt.toIso8601String(),
    );
  }

  factory ApplicationTrackerModel.fromMap(Map<dynamic, dynamic> map) {
    return ApplicationTrackerModel(
      id: map['id'] as String,
      opportunityId: map['opportunityId'] as String,
      title: map['title'] as String,
      organization: map['organization'] as String,
      type: map['type'] as String,
      sourceLink: map['sourceLink'] as String,
      status: map['status'] as String,
      appliedDate: map['appliedDate'] as String?,
      deadline: map['deadline'] as String,
      notes: (map['notes'] ?? '') as String,
      followUpDate: map['followUpDate'] as String?,
      requiredSkills: List<String>.from(
        map['requiredSkills'] as List? ?? const [],
      ),
      cvSuggestions: List<String>.from(
        map['cvSuggestions'] as List? ?? const [],
      ),
      savedAt: map['savedAt'] as String,
    );
  }

  ApplicationTrackerItem toDomain() {
    return ApplicationTrackerItem(
      id: id,
      opportunityId: opportunityId,
      title: title,
      organization: organization,
      type: ApplicationType.values.byName(type),
      sourceLink: sourceLink,
      status: ApplicationStatus.values.byName(status),
      appliedDate: appliedDate == null ? null : DateTime.parse(appliedDate!),
      deadline: DateTime.parse(deadline),
      notes: notes,
      followUpDate: followUpDate == null ? null : DateTime.parse(followUpDate!),
      requiredSkills: requiredSkills,
      cvSuggestions: cvSuggestions,
      savedAt: DateTime.parse(savedAt),
    );
  }

  @override
  Map<String, Object> toMap() => {
    'id': id,
    'opportunityId': opportunityId,
    'title': title,
    'organization': organization,
    'type': type,
    'sourceLink': sourceLink,
    'status': status,
    'appliedDate': ?appliedDate,
    'deadline': deadline,
    'notes': notes,
    'followUpDate': ?followUpDate,
    'requiredSkills': requiredSkills,
    'cvSuggestions': cvSuggestions,
    'savedAt': savedAt,
  };
}
