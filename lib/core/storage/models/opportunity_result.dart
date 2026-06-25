import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';

abstract interface class OpportunityResult {
  String get id;
  String get title;
  String get organization;
  String get location;
  String get sourceLink;
  DateTime get postedDate;
  DateTime get deadline;
  DateTime get foundAt;
  String get sourceName;
  OpportunityFreshness get freshnessStatus;
  List<String> get requiredSkills;
  int get matchScore;
  bool get fresherFriendly;
  bool get visaSponsorship;
  bool get trainingProvided;
  List<String> get whyMatch;
  List<String> get cvSuggestions;
}
