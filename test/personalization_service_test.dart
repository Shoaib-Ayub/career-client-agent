import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';
import 'package:career_client_agent/features/opportunities/service/personalization_service.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PersonalizationService();

  test('Flutter profile ranks Flutter jobs higher', () {
    final results = service.personalize(
      items: [
        _job(id: 'ai', title: 'Junior AI Engineer', skills: ['Python']),
        _job(id: 'flutter', title: 'Flutter Developer', skills: ['Flutter']),
      ],
      profile: _profile(skills: ['Flutter']),
      tasks: const [],
      taskType: SearchTaskType.job,
      enabled: true,
      strictMatch: false,
    );

    expect(results.first.id, 'flutter');
  });

  test('AI profile ranks AI and Computer Vision jobs higher', () {
    final results = service.personalize(
      items: [
        _job(id: 'web', title: 'Web Developer', skills: ['HTML']),
        _job(
          id: 'cv',
          title: 'Computer Vision Engineer',
          skills: ['Computer Vision'],
        ),
      ],
      profile: _profile(skills: ['Computer Vision']),
      tasks: const [],
      taskType: SearchTaskType.job,
      enabled: true,
      strictMatch: false,
    );

    expect(results.first.id, 'cv');
  });

  test('custom search task keyword affects ranking', () {
    final results = service.personalize(
      items: [
        _job(id: 'general', title: 'Flutter Developer', skills: ['Flutter']),
        _job(
          id: 'roboflow',
          title: 'Mobile AI App with Roboflow',
          skills: ['Flutter'],
        ),
      ],
      profile: null,
      tasks: [
        _task(id: 'active', keywords: ['Roboflow'], isActive: true),
      ],
      taskType: SearchTaskType.job,
      enabled: true,
      strictMatch: false,
    );

    expect(results.first.id, 'roboflow');
  });

  test('inactive tasks are ignored', () {
    final items = [
      _job(id: 'general', title: 'Flutter Developer', skills: ['Flutter']),
      _job(
        id: 'roboflow',
        title: 'Mobile AI App with Roboflow',
        skills: ['Flutter'],
      ),
    ];

    final results = service.personalize(
      items: items,
      profile: null,
      tasks: [
        _task(id: 'inactive', keywords: ['Roboflow'], isActive: false),
      ],
      taskType: SearchTaskType.job,
      enabled: true,
      strictMatch: false,
    );

    expect(results.map((item) => item.id), ['general', 'roboflow']);
  });

  test('no profile or tasks keeps global order', () {
    final items = [
      _job(id: 'first', title: 'First Global Job'),
      _job(id: 'second', title: 'Second Global Job'),
    ];

    final results = service.personalize(
      items: items,
      profile: null,
      tasks: const [],
      taskType: SearchTaskType.job,
      enabled: true,
      strictMatch: false,
    );

    expect(results.map((item) => item.id), ['first', 'second']);
  });

  test('strict mode hides unrelated results', () {
    final results = service.personalize(
      items: [
        _job(id: 'flutter', title: 'Flutter Developer', skills: ['Flutter']),
        _job(id: 'sales', title: 'Sales Officer', skills: ['Sales']),
      ],
      profile: _profile(skills: ['Flutter']),
      tasks: const [],
      taskType: SearchTaskType.job,
      enabled: true,
      strictMatch: true,
    );

    expect(results.map((item) => item.id), ['flutter']);
  });

  test('government jobs are not hidden unless strict mode is enabled', () {
    final governmentJobs = [
      _governmentJob(id: 'admin', title: 'Admin Officer'),
      _governmentJob(id: 'flutter', title: 'Flutter IT Officer'),
    ];

    final broadResults = service.personalize(
      items: governmentJobs,
      profile: _profile(skills: ['Flutter']),
      tasks: const [],
      taskType: SearchTaskType.governmentJob,
      enabled: true,
      strictMatch: false,
    );
    final strictResults = service.personalize(
      items: governmentJobs,
      profile: _profile(skills: ['Flutter']),
      tasks: const [],
      taskType: SearchTaskType.governmentJob,
      enabled: true,
      strictMatch: true,
    );

    expect(broadResults.map((item) => item.id), ['flutter', 'admin']);
    expect(strictResults.map((item) => item.id), ['flutter']);
  });
}

UserProfile _profile({
  List<String> skills = const [],
  List<String> preferredJobTypes = const [],
}) {
  return UserProfile(
    name: 'Test User',
    education: 'BS Software Engineering',
    cgpa: 3.5,
    skills: skills,
    location: 'Pakistan',
    careerGoals: '',
    preferredCountries: const [],
    preferredJobTypes: preferredJobTypes,
    experienceYears: 0,
  );
}

SearchTask _task({
  required String id,
  required List<String> keywords,
  required bool isActive,
}) {
  return SearchTask(
    id: id,
    taskType: SearchTaskType.job,
    title: 'Custom task',
    keywords: keywords,
    location: 'Remote',
    level: 'Entry',
    filters: const [],
    dailyLimit: 10,
    isActive: isActive,
    createdAt: DateTime(2026),
    lastRunAt: null,
  );
}

JobModel _job({
  required String id,
  required String title,
  List<String> skills = const [],
}) {
  final now = DateTime(2026, 7);
  return JobModel(
    id: id,
    title: title,
    organization: 'Company',
    location: 'Remote',
    sourceLink: 'https://example.com/$id',
    postedDate: now,
    deadline: now.add(const Duration(days: 30)),
    requiredSkills: skills,
    matchScore: 50,
    fresherFriendly: true,
    visaSponsorship: false,
    trainingProvided: false,
    whyMatch: const [],
    cvSuggestions: const [],
    requiredEducation: 'BS',
    minimumExperienceYears: 0,
    jobType: 'Remote',
    freshnessStatus: OpportunityFreshness.today,
  );
}

GovernmentJobModel _governmentJob({required String id, required String title}) {
  final now = DateTime(2026, 7);
  return GovernmentJobModel(
    id: id,
    title: title,
    organization: 'Government Department',
    location: 'Punjab',
    sourceLink: 'https://example.gov.pk/$id',
    postedDate: now,
    deadline: now.add(const Duration(days: 30)),
    requiredSkills: const [],
    matchScore: 50,
    fresherFriendly: true,
    visaSponsorship: false,
    trainingProvided: false,
    whyMatch: const [],
    cvSuggestions: const [],
    freshnessStatus: OpportunityFreshness.today,
    qualificationRequired: 'Bachelor degree',
    domicileRequired: 'Punjab',
    provinceEligibility: 'Punjab',
    eligibilityReason: 'Punjab bachelor eligible',
  );
}
