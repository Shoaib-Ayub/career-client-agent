import 'package:career_client_agent/core/constants/app_strings.dart';

enum OpportunityFilter {
  today,
  last24Hours,
  last7Days,
  all,
  latest,
  highestMatch,
  visaYes,
  fresherFriendly,
  deadlineSoon;

  String get label => switch (this) {
    OpportunityFilter.today => AppStrings.todayFilter,
    OpportunityFilter.last24Hours => AppStrings.last24HoursFilter,
    OpportunityFilter.last7Days => AppStrings.last7DaysFilter,
    OpportunityFilter.all => AppStrings.allFilter,
    OpportunityFilter.latest => AppStrings.latestFilter,
    OpportunityFilter.highestMatch => AppStrings.highestMatchFilter,
    OpportunityFilter.visaYes => AppStrings.visaYesFilter,
    OpportunityFilter.fresherFriendly => AppStrings.fresherFriendlyFilter,
    OpportunityFilter.deadlineSoon => AppStrings.deadlineSoonFilter,
  };
}
