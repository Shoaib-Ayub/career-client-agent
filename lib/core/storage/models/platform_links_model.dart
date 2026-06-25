import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/features/profile_optimizer/model/platform_links.dart';

class PlatformLinksModel implements LocalModel {
  const PlatformLinksModel({
    required this.linkedIn,
    required this.github,
    required this.portfolio,
    required this.kaggle,
  });

  @override
  String get id => AppConstants.platformLinksRecordId;

  final String linkedIn;
  final String github;
  final String portfolio;
  final String kaggle;

  factory PlatformLinksModel.fromDomain(PlatformLinks links) {
    return PlatformLinksModel(
      linkedIn: links.linkedIn,
      github: links.github,
      portfolio: links.portfolio,
      kaggle: links.kaggle,
    );
  }

  factory PlatformLinksModel.fromMap(Map<dynamic, dynamic> map) {
    return PlatformLinksModel(
      linkedIn: (map['linkedIn'] ?? '') as String,
      github: (map['github'] ?? '') as String,
      portfolio: (map['portfolio'] ?? '') as String,
      kaggle: (map['kaggle'] ?? '') as String,
    );
  }

  PlatformLinks toDomain() => PlatformLinks(
    linkedIn: linkedIn,
    github: github,
    portfolio: portfolio,
    kaggle: kaggle,
  );

  @override
  Map<String, Object> toMap() => {
    'linkedIn': linkedIn,
    'github': github,
    'portfolio': portfolio,
    'kaggle': kaggle,
  };
}
