import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';

class PersonalizationService {
  const PersonalizationService();

  List<T> personalize<T extends OpportunityResult>({
    required List<T> items,
    required UserProfile? profile,
    required List<SearchTask> tasks,
    required SearchTaskType taskType,
    required bool enabled,
    required bool strictMatch,
  }) {
    final activeTasks = tasks
        .where((task) => task.isActive && task.taskType == taskType)
        .toList();
    if (!enabled || (profile == null && activeTasks.isEmpty)) {
      return items;
    }

    final context = _PersonalizationContext.from(
      profile: profile,
      tasks: activeTasks,
    );
    if (!context.hasSignals) {
      return items;
    }

    final scored = [
      for (var index = 0; index < items.length; index++)
        _ScoredOpportunity(
          item: items[index],
          score: _score(items[index], context),
          originalIndex: index,
        ),
    ];

    final visible = scored.where((entry) {
      if (!strictMatch) {
        return true;
      }
      return entry.score > 0;
    }).toList();

    visible.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }

      final matchScore = b.item.matchScore.compareTo(a.item.matchScore);
      if (matchScore != 0) {
        return matchScore;
      }

      return a.originalIndex.compareTo(b.originalIndex);
    });

    return visible.map((entry) => entry.item).toList();
  }

  int _score(OpportunityResult opportunity, _PersonalizationContext context) {
    final searchable = _searchableText(opportunity);
    var score = 0;

    for (final skill in context.skills) {
      if (_containsPhrase(searchable, skill) ||
          opportunity.requiredSkills.any(
            (requiredSkill) => _samePhrase(requiredSkill, skill),
          )) {
        score += 30;
      }
    }

    for (final keyword in context.taskKeywords) {
      if (_containsPhrase(searchable, keyword)) {
        score += 25;
      }
    }

    for (final role in context.roles) {
      if (_containsPhrase(searchable, role)) {
        score += 15;
      }
    }

    for (final location in context.locations) {
      if (_containsPhrase(searchable, location)) {
        score += 10;
      }
    }

    if (context.prefersRemote &&
        (_containsPhrase(searchable, AppStrings.remoteLocation) ||
            _containsPhrase(opportunity.location, AppStrings.remoteLocation))) {
      score += 10;
    }

    return score;
  }

  String _searchableText(OpportunityResult opportunity) {
    final parts = <String>[
      opportunity.title,
      opportunity.organization,
      opportunity.location,
      opportunity.sourceName,
      ...opportunity.requiredSkills,
      ...opportunity.whyMatch,
      ...opportunity.cvSuggestions,
    ];

    if (opportunity case GovernmentJobModel job) {
      parts.addAll([
        job.qualificationRequired,
        job.domicileRequired,
        job.provinceEligibility,
        job.eligibilityReason,
        job.forceCategory,
        job.jobScale,
      ]);
    }

    if (opportunity case ClientLeadModel lead) {
      parts.addAll([
        lead.leadCategory,
        lead.platform,
        lead.country,
        lead.whyGoodLead.join(AppConstants.listDisplaySeparator),
        lead.expectedLeadType,
        lead.searchKeyword,
      ]);
    }

    return parts.join(' ').toLowerCase();
  }

  bool _containsPhrase(String source, String phrase) {
    final normalizedSource = source.toLowerCase();
    final normalizedPhrase = phrase.toLowerCase().trim();
    if (normalizedPhrase.length < 2) {
      return false;
    }
    return normalizedSource.contains(normalizedPhrase);
  }

  bool _samePhrase(String left, String right) {
    return left.toLowerCase().trim() == right.toLowerCase().trim();
  }
}

class _PersonalizationContext {
  const _PersonalizationContext({
    required this.skills,
    required this.taskKeywords,
    required this.roles,
    required this.locations,
    required this.prefersRemote,
  });

  final Set<String> skills;
  final Set<String> taskKeywords;
  final Set<String> roles;
  final Set<String> locations;
  final bool prefersRemote;

  bool get hasSignals =>
      skills.isNotEmpty ||
      taskKeywords.isNotEmpty ||
      roles.isNotEmpty ||
      locations.isNotEmpty ||
      prefersRemote;

  factory _PersonalizationContext.from({
    required UserProfile? profile,
    required List<SearchTask> tasks,
  }) {
    final skills = <String>{};
    final taskKeywords = <String>{};
    final roles = <String>{};
    final locations = <String>{};

    if (profile != null) {
      skills.addAll(_cleanList(profile.skills));
      roles.addAll(_cleanList(profile.preferredJobTypes));
      roles.addAll(_splitKeywords(profile.careerGoals));
      locations.addAll(_cleanList(profile.preferredCountries));
      locations.addAll(_splitKeywords(profile.location));
    }

    for (final task in tasks) {
      taskKeywords.addAll(_cleanList(task.keywords));
      taskKeywords.addAll(_splitKeywords(task.title));
      taskKeywords.addAll(_splitKeywords(task.level));
      taskKeywords.addAll(_cleanList(task.filters));
      locations.addAll(_splitKeywords(task.location));
    }

    return _PersonalizationContext(
      skills: skills,
      taskKeywords: taskKeywords,
      roles: roles,
      locations: locations,
      prefersRemote:
          _containsAny(profile?.preferredJobTypes ?? const [], 'remote') ||
          tasks.any((task) => task.location.toLowerCase().contains('remote')),
    );
  }

  static Iterable<String> _cleanList(Iterable<String> values) {
    return values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.length > 1);
  }

  static Iterable<String> _splitKeywords(String value) {
    return value
        .split(RegExp(r'[,/|]|\s+-\s+'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.length > 1);
  }

  static bool _containsAny(Iterable<String> values, String phrase) {
    return values.any((value) => value.toLowerCase().contains(phrase));
  }
}

class _ScoredOpportunity<T extends OpportunityResult> {
  const _ScoredOpportunity({
    required this.item,
    required this.score,
    required this.originalIndex,
  });

  final T item;
  final int score;
  final int originalIndex;
}
