import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/application_tracker/model/apply_assistant_result.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';

class ApplyAssistantService {
  const ApplyAssistantService();

  ApplyAssistantResult generate({
    required ApplicationTrackerItem item,
    required UserProfile profile,
  }) {
    final profileSkills = profile.skills.map(_normalize).toSet();
    final missingSkills = item.requiredSkills
        .where((skill) => !profileSkills.contains(_normalize(skill)))
        .toList();
    final cvChanges = [
      ...item.cvSuggestions,
      ...missingSkills.map(
        (skill) => AppStrings.labeledValue(AppStrings.skillsLabel, skill),
      ),
    ];
    final skills = item.requiredSkills.isEmpty
        ? AppStrings.professionalLevel
        : item.requiredSkills.join(AppConstants.listDisplaySeparator);

    return ApplyAssistantResult(
      cvChanges: cvChanges.isEmpty
          ? const [AppStrings.noCvChangesNeeded]
          : cvChanges,
      coverLetterDraft: [
        AppStrings.coverLetterGreeting,
        AppStrings.coverLetterIntro(item.title, item.organization),
        AppStrings.coverLetterSkills(skills),
        AppStrings.coverLetterClosing,
      ].join('\n\n'),
      outreachMessageDraft: [
        AppStrings.outreachGreeting,
        AppStrings.outreachIntro(item.title, item.organization),
        AppStrings.coverLetterSkills(skills),
        AppStrings.outreachClosing,
      ].join('\n\n'),
      requiredDocuments: _documents(item.type),
    );
  }

  List<String> _documents(ApplicationType type) => switch (type) {
    ApplicationType.job => const [
      AppStrings.documentCv,
      AppStrings.documentCoverLetter,
      AppStrings.documentPortfolio,
      AppStrings.documentReferences,
    ],
    ApplicationType.scholarship => const [
      AppStrings.documentCv,
      AppStrings.documentCoverLetter,
      AppStrings.documentEducation,
      AppStrings.documentIdentity,
      AppStrings.documentReferences,
    ],
    ApplicationType.govtJob => const [
      AppStrings.documentApplicationForm,
      AppStrings.documentCv,
      AppStrings.documentEducation,
      AppStrings.documentIdentity,
    ],
    ApplicationType.clientLead => const [
      AppStrings.documentPortfolio,
      AppStrings.documentCv,
      AppStrings.documentCoverLetter,
    ],
  };

  String _normalize(String value) => value.trim().toLowerCase();
}
