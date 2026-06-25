import 'package:career_client_agent/core/constants/app_strings.dart';

enum OpportunityFreshness {
  today('today'),
  last24Hours('last_24_hours'),
  last7Days('last_7_days'),
  older('older'),
  unknown('unknown');

  const OpportunityFreshness(this.value);

  final String value;

  static OpportunityFreshness fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => OpportunityFreshness.unknown,
    );
  }

  String get label => switch (this) {
    OpportunityFreshness.today => AppStrings.todayFilter,
    OpportunityFreshness.last24Hours => AppStrings.last24HoursFilter,
    OpportunityFreshness.last7Days => AppStrings.last7DaysFilter,
    OpportunityFreshness.older => AppStrings.olderFreshness,
    OpportunityFreshness.unknown => AppStrings.unknownFreshness,
  };

  int get priority => switch (this) {
    OpportunityFreshness.today => 0,
    OpportunityFreshness.last24Hours => 1,
    OpportunityFreshness.last7Days => 2,
    OpportunityFreshness.unknown => 3,
    OpportunityFreshness.older => 4,
  };
}
