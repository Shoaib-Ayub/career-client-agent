import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/models/scholarship_model.dart';
import 'package:career_client_agent/core/storage/models/user_profile_model.dart';
import 'package:career_client_agent/features/client_leads/repository/client_leads_repository.dart';
import 'package:career_client_agent/features/government_jobs/repository/government_jobs_repository.dart';
import 'package:career_client_agent/features/jobs/repository/jobs_repository.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/profile/repository/profile_repository.dart';
import 'package:career_client_agent/features/scholarships/repository/scholarships_repository.dart';
import 'package:career_client_agent/features/search_tasks/repository/search_tasks_repository.dart';
import 'package:career_client_agent/features/search_tasks/service/default_task_factory.dart';

class LocalDatabaseService {
  const LocalDatabaseService();

  Future<void> seedInitialData() async {
    const storage = LocalStorageService();
    final jobs = JobsRepository(storage);
    final scholarships = ScholarshipsRepository(storage);
    final governmentJobs = GovernmentJobsRepository(storage);
    final clientLeads = ClientLeadsRepository(storage);
    final searchTasks = SearchTasksRepository(storage);
    final profiles = ProfileRepository(storage);
    final today = _today();

    const profile = UserProfile(
      name: AppStrings.profilePlaceholderName,
      education: AppStrings.mockProfileEducation,
      cgpa: AppConstants.defaultCgpa,
      skills: [
        AppStrings.mockSkillFlutter,
        AppStrings.mockSkillDart,
        AppStrings.mockSkillGit,
      ],
      location: AppStrings.mockProfileLocation,
      careerGoals: AppStrings.mockProfileCareerGoals,
      preferredCountries: [
        AppStrings.mockCountryGermany,
        AppStrings.mockCountryUae,
      ],
      preferredJobTypes: [
        AppStrings.mockJobTypeFullTime,
        AppStrings.mockJobTypeRemote,
      ],
      experienceYears: AppConstants.defaultExperienceYears,
    );

    if (await profiles.isEmpty) {
      await profiles.create(UserProfileModel.fromDomain(profile));
    }

    await jobs.createAll(_sampleJobs(today));
    await scholarships.createAll(_sampleScholarships(today));
    await governmentJobs.createAll(_sampleGovernmentJobs(today));
    await clientLeads.createAll(_sampleClientLeads(today));
    await searchTasks.ensureDefaultTasks(
      const DefaultTaskFactory().create(profile),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<JobModel> _sampleJobs(DateTime today) => [
    JobModel(
      id: AppConstants.sampleJobId,
      title: AppStrings.mockJobTitle,
      organization: AppStrings.mockJobCompany,
      location: AppStrings.mockJobLocation,
      sourceLink: AppStrings.sampleJobSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleDeadlineDays),
      ),
      requiredSkills: const [
        AppStrings.mockSkillFlutter,
        AppStrings.mockSkillDart,
        AppStrings.mockSkillRestApis,
        AppStrings.mockSkillGit,
        AppStrings.mockSkillRiverpod,
      ],
      matchScore: AppConstants.highMatchScore,
      fresherFriendly: true,
      visaSponsorship: true,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleWhyMatch],
      cvSuggestions: const [AppStrings.sampleCvSuggestion],
      requiredEducation: AppStrings.mockJobEducation,
      minimumExperienceYears: AppConstants.mockRequiredExperienceYears,
      jobType: AppStrings.mockJobType,
    ),
    JobModel(
      id: AppConstants.sampleJobTwoId,
      title: AppStrings.sampleJobTwoTitle,
      organization: AppStrings.sampleJobTwoOrganization,
      location: AppStrings.remoteLocation,
      sourceLink: AppStrings.sampleJobTwoSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleLaterDeadlineDays),
      ),
      requiredSkills: const [
        AppStrings.aiJobsKeywords,
        AppStrings.mockSkillRestApis,
      ],
      matchScore: AppConstants.defaultMatchScore,
      fresherFriendly: true,
      visaSponsorship: false,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleAiWhyMatch],
      cvSuggestions: const [AppStrings.sampleAiCvSuggestion],
      requiredEducation: AppStrings.mockJobEducation,
      minimumExperienceYears: AppConstants.defaultExperienceYears,
      jobType: AppStrings.mockJobTypeRemote,
    ),
  ];

  List<ScholarshipModel> _sampleScholarships(DateTime today) => [
    ScholarshipModel(
      id: AppConstants.sampleScholarshipId,
      title: AppStrings.sampleScholarshipTitle,
      organization: AppStrings.sampleScholarshipProvider,
      location: AppStrings.mockCountryGermany,
      sourceLink: AppStrings.sampleScholarshipSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleDeadlineDays),
      ),
      requiredSkills: const [AppStrings.sampleScholarshipField],
      matchScore: AppConstants.highMatchScore,
      fresherFriendly: true,
      visaSponsorship: true,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleAiWhyMatch],
      cvSuggestions: const [AppStrings.sampleScholarshipCvSuggestion],
    ),
    ScholarshipModel(
      id: AppConstants.sampleScholarshipTwoId,
      title: AppStrings.sampleScholarshipTwoTitle,
      organization: AppStrings.sampleScholarshipTwoProvider,
      location: AppStrings.globalLocation,
      sourceLink: AppStrings.sampleScholarshipTwoSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleLaterDeadlineDays),
      ),
      requiredSkills: const [
        AppStrings.mockSkillDart,
        AppStrings.aiJobsKeywords,
      ],
      matchScore: AppConstants.defaultMatchScore,
      fresherFriendly: true,
      visaSponsorship: true,
      trainingProvided: false,
      whyMatch: const [AppStrings.sampleAiWhyMatch],
      cvSuggestions: const [AppStrings.sampleScholarshipCvSuggestion],
    ),
  ];

  List<GovernmentJobModel> _sampleGovernmentJobs(DateTime today) => [
    GovernmentJobModel(
      id: AppConstants.sampleGovernmentJobId,
      title: AppStrings.sampleGovernmentJobTitle,
      organization: AppStrings.sampleGovernmentDepartment,
      location: AppStrings.mockProfileLocation,
      sourceLink: AppStrings.sampleGovernmentSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleDeadlineDays),
      ),
      requiredSkills: const [AppStrings.mockSkillDart, AppStrings.mockSkillGit],
      matchScore: AppConstants.highMatchScore,
      fresherFriendly: true,
      visaSponsorship: false,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleWhyMatch],
      cvSuggestions: const [AppStrings.sampleGovernmentCvSuggestion],
    ),
    GovernmentJobModel(
      id: AppConstants.sampleGovernmentJobTwoId,
      title: AppStrings.sampleGovernmentTwoTitle,
      organization: AppStrings.sampleGovernmentTwoOrganization,
      location: AppStrings.pakistanPunjabLocation,
      sourceLink: AppStrings.sampleGovernmentTwoSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleLaterDeadlineDays),
      ),
      requiredSkills: const [
        AppStrings.mockSkillRestApis,
        AppStrings.mockSkillGit,
      ],
      matchScore: AppConstants.defaultMatchScore,
      fresherFriendly: false,
      visaSponsorship: false,
      trainingProvided: false,
      whyMatch: const [AppStrings.sampleWhyMatch],
      cvSuggestions: const [AppStrings.sampleGovernmentCvSuggestion],
    ),
  ];

  List<ClientLeadModel> _sampleClientLeads(DateTime today) => [
    ClientLeadModel(
      id: AppConstants.sampleClientLeadId,
      title: AppStrings.sampleClientService,
      organization: AppStrings.sampleClientCompany,
      location: AppStrings.remoteLocation,
      sourceLink: AppStrings.sampleClientSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleDeadlineDays),
      ),
      requiredSkills: const [
        AppStrings.mockSkillFlutter,
        AppStrings.mockSkillDart,
      ],
      matchScore: AppConstants.highMatchScore,
      fresherFriendly: true,
      visaSponsorship: false,
      trainingProvided: false,
      whyMatch: const [AppStrings.sampleWhyMatch],
      cvSuggestions: const [AppStrings.sampleCvSuggestion],
      leadCategory: AppStrings.defaultClientTaskTitle,
      budget: AppStrings.unknownBudget,
      budgetType: AppStrings.emptyValue,
      country: AppStrings.remoteLocation,
      platform: AppStrings.appName,
      proposalUrl: AppStrings.sampleClientSource,
      leadScore: AppConstants.highMatchScore,
      whyGoodLead: const [AppStrings.sampleWhyMatch],
      suggestedMessage: AppStrings.outreachIntro(
        AppStrings.sampleClientService,
        AppStrings.sampleClientCompany,
      ),
    ),
    ClientLeadModel(
      id: AppConstants.sampleClientLeadTwoId,
      title: AppStrings.sampleClientTwoTitle,
      organization: AppStrings.sampleClientTwoOrganization,
      location: AppStrings.remoteLocation,
      sourceLink: AppStrings.sampleClientTwoSource,
      postedDate: today,
      deadline: today.add(
        const Duration(days: AppConstants.sampleLaterDeadlineDays),
      ),
      requiredSkills: const [
        AppStrings.aiClientKeywords,
        AppStrings.mockSkillFlutter,
      ],
      matchScore: AppConstants.defaultMatchScore,
      fresherFriendly: false,
      visaSponsorship: false,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleAiWhyMatch],
      cvSuggestions: const [AppStrings.sampleAiCvSuggestion],
      leadCategory: AppStrings.defaultClientTaskTitle,
      budget: AppStrings.unknownBudget,
      budgetType: AppStrings.emptyValue,
      country: AppStrings.remoteLocation,
      platform: AppStrings.appName,
      proposalUrl: AppStrings.sampleClientTwoSource,
      leadScore: AppConstants.defaultMatchScore,
      whyGoodLead: const [AppStrings.sampleAiWhyMatch],
      suggestedMessage: AppStrings.outreachIntro(
        AppStrings.sampleClientTwoTitle,
        AppStrings.sampleClientTwoOrganization,
      ),
    ),
  ];
}
