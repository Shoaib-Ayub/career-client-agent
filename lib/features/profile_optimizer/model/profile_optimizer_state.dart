import 'package:career_client_agent/features/profile_optimizer/model/platform_links.dart';
import 'package:career_client_agent/features/profile_optimizer/model/profile_optimization.dart';

class ProfileOptimizerState {
  const ProfileOptimizerState({
    required this.links,
    required this.optimization,
  });

  final PlatformLinks links;
  final ProfileOptimization optimization;

  ProfileOptimizerState copyWith({PlatformLinks? links}) {
    return ProfileOptimizerState(
      links: links ?? this.links,
      optimization: optimization,
    );
  }
}
