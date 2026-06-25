import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';
import 'package:career_client_agent/features/opportunities/service/opportunity_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = OpportunityFilterService();
  final now = DateTime.now();
  late List<JobModel> jobs;

  setUp(() {
    jobs = [
      _job(
        id: AppConstants.sampleJobId,
        postedDate: now,
        deadline: now.add(
          const Duration(days: AppConstants.sampleDeadlineDays),
        ),
        matchScore: AppConstants.defaultMatchScore,
        visa: true,
        fresher: true,
        freshness: OpportunityFreshness.today,
      ),
      _job(
        id: AppConstants.sampleJobTwoId,
        postedDate: now.subtract(
          const Duration(days: AppConstants.sampleDeadlineDays),
        ),
        deadline: now.add(
          const Duration(days: AppConstants.sampleLaterDeadlineDays),
        ),
        matchScore: AppConstants.highMatchScore,
        visa: false,
        fresher: false,
        freshness: OpportunityFreshness.last7Days,
      ),
    ];
  });

  test('applies all opportunity filters', () {
    expect(
      service.apply(jobs, OpportunityFilter.latest).first.id,
      AppConstants.sampleJobId,
    );
    expect(service.apply(jobs, OpportunityFilter.today), hasLength(1));
    expect(service.apply(jobs, OpportunityFilter.last24Hours), hasLength(1));
    expect(service.apply(jobs, OpportunityFilter.last7Days), hasLength(2));
    expect(service.apply(jobs, OpportunityFilter.all), hasLength(2));
    expect(
      service.apply(jobs, OpportunityFilter.highestMatch).first.id,
      AppConstants.sampleJobTwoId,
    );
    expect(service.apply(jobs, OpportunityFilter.visaYes), hasLength(1));
    expect(
      service.apply(jobs, OpportunityFilter.fresherFriendly),
      hasLength(1),
    );
    expect(service.apply(jobs, OpportunityFilter.deadlineSoon), hasLength(1));
  });
}

JobModel _job({
  required String id,
  required DateTime postedDate,
  required DateTime deadline,
  required int matchScore,
  required bool visa,
  required bool fresher,
  required OpportunityFreshness freshness,
}) {
  return JobModel(
    id: id,
    title: AppStrings.mockJobTitle,
    organization: AppStrings.mockJobCompany,
    location: AppStrings.mockJobLocation,
    sourceLink: AppStrings.sampleJobSource,
    postedDate: postedDate,
    deadline: deadline,
    requiredSkills: const [AppStrings.mockSkillFlutter],
    matchScore: matchScore,
    fresherFriendly: fresher,
    visaSponsorship: visa,
    trainingProvided: true,
    whyMatch: const [AppStrings.sampleWhyMatch],
    cvSuggestions: const [AppStrings.sampleCvSuggestion],
    requiredEducation: AppStrings.mockJobEducation,
    minimumExperienceYears: AppConstants.defaultExperienceYears,
    jobType: AppStrings.mockJobType,
    freshnessStatus: freshness,
  );
}
