import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';

abstract final class OpportunityModelDecoder {
  static DateTime date(Object? value, {required DateTime fallback}) {
    return value is String ? DateTime.tryParse(value) ?? fallback : fallback;
  }

  static List<String> strings(
    Object? value, {
    List<String> fallback = const [],
  }) {
    return value is List ? List<String>.from(value) : fallback;
  }

  static int score(Object? value) {
    return value is int ? value : AppConstants.defaultMatchScore;
  }

  static int? nullableInteger(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static bool boolean(Object? value, {bool fallback = false}) {
    return value is bool ? value : fallback;
  }

  static List<String> whyMatch(Object? value) {
    return strings(value, fallback: const [AppStrings.sampleWhyMatch]);
  }

  static List<String> cvSuggestions(Object? value) {
    return strings(value, fallback: const [AppStrings.sampleCvSuggestion]);
  }
}
