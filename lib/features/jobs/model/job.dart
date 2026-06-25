import 'package:flutter/foundation.dart';

@immutable
class Job {
  const Job({
    required this.title,
    required this.company,
    required this.requiredSkills,
    required this.requiredEducation,
    required this.minimumExperienceYears,
    required this.location,
    required this.jobType,
    required this.offersVisaSponsorship,
  });

  final String title;
  final String company;
  final List<String> requiredSkills;
  final String requiredEducation;
  final int minimumExperienceYears;
  final String location;
  final String jobType;
  final bool offersVisaSponsorship;
}
