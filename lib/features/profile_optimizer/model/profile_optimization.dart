class ProfileOptimization {
  const ProfileOptimization({
    required this.linkedInHeadline,
    required this.aboutSectionDraft,
    required this.skillsToAdd,
    required this.featuredProjectsOrder,
    required this.projectDescriptions,
    required this.recruiterMessageTemplate,
    required this.githubReadmeSuggestions,
    required this.portfolioHeroSection,
  });

  final String linkedInHeadline;
  final String aboutSectionDraft;
  final List<String> skillsToAdd;
  final List<String> featuredProjectsOrder;
  final List<String> projectDescriptions;
  final String recruiterMessageTemplate;
  final List<String> githubReadmeSuggestions;
  final String portfolioHeroSection;
}
