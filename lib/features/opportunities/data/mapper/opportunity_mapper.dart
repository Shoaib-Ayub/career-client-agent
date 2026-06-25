import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/opportunities/data/dto/opportunity_dto.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';

abstract final class OpportunityMapper {
  static DateTime postedDate(OpportunityDto dto) {
    return DateTime.tryParse(dto.postedDate) ?? DateTime.now();
  }

  static DateTime deadline(OpportunityDto dto) {
    return DateTime.tryParse(dto.deadline) ??
        DateTime.now().add(const Duration(days: AppConstants.deadlineSoonDays));
  }

  static DateTime foundAt(OpportunityDto dto) {
    return DateTime.tryParse(dto.foundAt) ?? postedDate(dto);
  }

  static OpportunityFreshness freshnessStatus(OpportunityDto dto) {
    return OpportunityFreshness.fromValue(dto.freshnessStatus);
  }

  static List<String> whyMatch(OpportunityDto dto) {
    return dto.whyMatch.isEmpty
        ? const [AppStrings.sampleWhyMatch]
        : dto.whyMatch;
  }

  static List<String> cvSuggestions(OpportunityDto dto) {
    return dto.cvSuggestions.isEmpty
        ? const [AppStrings.sampleCvSuggestion]
        : dto.cvSuggestions;
  }
}
