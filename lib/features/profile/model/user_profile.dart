import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.name,
    required this.education,
    required this.cgpa,
    required this.skills,
    required this.location,
    required this.careerGoals,
    required this.preferredCountries,
    required this.preferredJobTypes,
    required this.experienceYears,
  });

  final String name;
  final String education;
  final double cgpa;
  final List<String> skills;
  final String location;
  final String careerGoals;
  final List<String> preferredCountries;
  final List<String> preferredJobTypes;
  final int experienceYears;

  UserProfile copyWith({
    String? name,
    String? education,
    double? cgpa,
    List<String>? skills,
    String? location,
    String? careerGoals,
    List<String>? preferredCountries,
    List<String>? preferredJobTypes,
    int? experienceYears,
  }) {
    return UserProfile(
      name: name ?? this.name,
      education: education ?? this.education,
      cgpa: cgpa ?? this.cgpa,
      skills: skills ?? this.skills,
      location: location ?? this.location,
      careerGoals: careerGoals ?? this.careerGoals,
      preferredCountries: preferredCountries ?? this.preferredCountries,
      preferredJobTypes: preferredJobTypes ?? this.preferredJobTypes,
      experienceYears: experienceYears ?? this.experienceYears,
    );
  }
}
