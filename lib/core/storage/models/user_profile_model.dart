import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';

class UserProfileModel implements LocalModel {
  const UserProfileModel({
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

  @override
  String get id => AppConstants.profileRecordId;

  final String name;
  final String education;
  final double cgpa;
  final List<String> skills;
  final String location;
  final String careerGoals;
  final List<String> preferredCountries;
  final List<String> preferredJobTypes;
  final int experienceYears;

  factory UserProfileModel.fromDomain(UserProfile profile) => UserProfileModel(
    name: profile.name,
    education: profile.education,
    cgpa: profile.cgpa,
    skills: profile.skills,
    location: profile.location,
    careerGoals: profile.careerGoals,
    preferredCountries: profile.preferredCountries,
    preferredJobTypes: profile.preferredJobTypes,
    experienceYears: profile.experienceYears,
  );

  factory UserProfileModel.fromMap(Map<dynamic, dynamic> map) =>
      UserProfileModel(
        name: map['name'] as String,
        education: map['education'] as String,
        cgpa: (map['cgpa'] as num).toDouble(),
        skills: List<String>.from(map['skills'] as List),
        location: map['location'] as String,
        careerGoals: map['careerGoals'] as String,
        preferredCountries: List<String>.from(
          map['preferredCountries'] as List,
        ),
        preferredJobTypes: List<String>.from(map['preferredJobTypes'] as List),
        experienceYears: map['experienceYears'] as int,
      );

  UserProfile toDomain() => UserProfile(
    name: name,
    education: education,
    cgpa: cgpa,
    skills: skills,
    location: location,
    careerGoals: careerGoals,
    preferredCountries: preferredCountries,
    preferredJobTypes: preferredJobTypes,
    experienceYears: experienceYears,
  );

  @override
  Map<String, Object> toMap() => {
    'name': name,
    'education': education,
    'cgpa': cgpa,
    'skills': skills,
    'location': location,
    'careerGoals': careerGoals,
    'preferredCountries': preferredCountries,
    'preferredJobTypes': preferredJobTypes,
    'experienceYears': experienceYears,
  };
}
