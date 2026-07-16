from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Iterable, Sequence

from ..models import SearchTask
from ..profile_match_engine import Profile


@dataclass(frozen=True, slots=True)
class CriteriaScore:
    score: int
    matched_terms: tuple[str, ...]


class AgentPersonalizationService:
    """Rank collected opportunities using the active task and local profile.

    The backend still collects from broad public sources, but this service makes
    the saved JSON follow the user's own profile/search-task intent before the
    daily limit is applied.
    """

    _GENERIC_TERMS = {
        "",
        "all",
        "any",
        "daily",
        "job",
        "jobs",
        "search",
        "latest",
        "opportunity",
        "opportunities",
        "government",
        "public",
        "private",
        "pakistan",
        "worldwide",
    }
    _TERM_ALIASES = {
        "ai": ("artificial intelligence", "machine learning", "ai", "ml"),
        "ai/ml": ("artificial intelligence", "machine learning", "ai", "ml"),
        "ml": ("machine learning", "ml"),
        "cv": ("computer vision", "object detection", "opencv"),
        "tflite": ("tensorflow lite", "tflite"),
        "tensorflow lite": ("tensorflow lite", "tflite"),
        "yolo": ("yolo", "object detection"),
        "bs": ("bachelor", "bachelors", "graduation", "16 years education"),
        "bachelor": ("bachelor", "bachelors", "graduation", "16 years education"),
    }

    def rank_items(
        self,
        items: Sequence[Any],
        task: SearchTask,
        profile: Profile | None,
        *,
        preserve_all: bool = False,
    ) -> list[Any]:
        """Return items ranked by user criteria.

        When strong criteria exists and some items match it, non-matching items
        are dropped for normal jobs/scholarships. For broad government jobs we
        pass preserve_all=True so valid Punjab/BS jobs are not hidden only
        because they are outside the user's technical field.
        """

        if not items:
            return []

        scored: list[tuple[CriteriaScore, int, Any]] = [
            (self.score_item(item, task, profile), index, item)
            for index, item in enumerate(items)
        ]
        has_criteria = self._has_criteria(task, profile)
        if not has_criteria:
            return list(items)
        has_positive_match = any(score.score > 0 for score, _, _ in scored)
        if has_criteria and has_positive_match and not preserve_all:
            scored = [
                (score, index, item)
                for score, index, item in scored
                if score.score > 0
            ]

        for score, _, item in scored:
            self._append_match_reason(item, score)

        return [
            item
            for score, index, item in sorted(
                scored,
                key=lambda value: (
                    -value[0].score,
                    -self._existing_score(value[2]),
                    self._field(value[2], "platform", "source_name").casefold(),
                    self._field(value[2], "title").casefold(),
                    value[1],
                ),
            )
        ]

    def score_item(
        self,
        item: Any,
        task: SearchTask,
        profile: Profile | None,
    ) -> CriteriaScore:
        title_text = self._normalize(self._field(item, "title"))
        location_text = self._normalize(self._field(item, "location", "country"))
        full_text = self._searchable_text(item)
        matched: list[str] = []
        score = 0

        for term in self._expanded_terms(task.keywords):
            if self._contains(full_text, term):
                matched.append(term)
                score += 35
                if self._contains(title_text, term):
                    score += 20

        for term in self._expanded_terms([task.title, task.level, *task.filters]):
            if self._contains(full_text, term):
                matched.append(term)
                score += 15

        if task.location and self._contains(location_text, task.location):
            matched.append(task.location)
            score += 20

        if profile is not None:
            for term in self._expanded_terms(profile.skills):
                if self._contains(full_text, term):
                    matched.append(term)
                    score += 30
                    if self._contains(title_text, term):
                        score += 15

            for term in self._expanded_terms(profile.preferred_job_types):
                if self._contains(full_text, term):
                    matched.append(term)
                    score += 15

            for term in self._expanded_terms(
                [profile.location, *profile.preferred_countries],
            ):
                if term and self._contains(location_text, term):
                    matched.append(term)
                    score += 15

            for term in self._expanded_terms([profile.education]):
                if self._contains(full_text, term):
                    matched.append(term)
                    score += 10

        if self._wants_remote(task, profile) and self._looks_remote(item):
            matched.append("remote")
            score += 15

        if self._wants_visa_or_relocation(task) and self._has_visa_or_relocation(item):
            matched.append("visa/relocation")
            score += 25

        return CriteriaScore(
            score=max(0, score),
            matched_terms=tuple(dict.fromkeys(matched)),
        )

    def _has_criteria(self, task: SearchTask, profile: Profile | None) -> bool:
        task_values = [
            *task.keywords,
            task.location,
            task.level,
            *task.filters,
        ]
        profile_values: Iterable[str] = []
        if profile is not None:
            profile_values = [
                *profile.skills,
                profile.education,
                profile.location,
                *profile.preferred_countries,
                *profile.preferred_job_types,
            ]
        return any(self._candidate_terms([*task_values, *profile_values]))

    def _candidate_terms(self, values: Iterable[str]) -> list[str]:
        terms: list[str] = []
        for value in values:
            normalized = self._normalize(value)
            if not normalized:
                continue
            if normalized in self._GENERIC_TERMS:
                continue
            if len(normalized) < 2:
                continue
            terms.append(normalized)
        return terms

    def _expanded_terms(self, values: Iterable[str]) -> list[str]:
        terms: list[str] = []
        for term in self._candidate_terms(values):
            terms.append(term)
            terms.extend(self._TERM_ALIASES.get(term, ()))
        return list(dict.fromkeys(terms))

    def _searchable_text(self, item: Any) -> str:
        values: list[str] = []
        for name in (
            "title",
            "organization",
            "location",
            "description",
            "source_name",
            "required_education",
            "eligibility_domicile",
            "match_reason",
            "remote_status",
            "visa_sponsorship_status",
            "relocation_support_status",
            "lead_category",
            "platform",
            "budget",
            "country",
            "expected_lead_type",
            "search_keyword",
            "source_link",
            "proposal_url",
        ):
            value = self._field(item, name)
            if value:
                values.append(value)
        skills = self._field_list(item, "required_skills", "skills")
        values.extend(skills)
        why_good = self._field_list(item, "why_good_lead")
        values.extend(why_good)
        return self._normalize(" ".join(values))

    def _append_match_reason(self, item: Any, score: CriteriaScore) -> None:
        if score.score <= 0 or not hasattr(item, "match_reason"):
            return
        summary_terms = ", ".join(score.matched_terms[:5])
        if not summary_terms:
            return
        addition = f"Matches user profile/task criteria: {summary_terms}."
        current = str(getattr(item, "match_reason", "") or "").strip()
        if addition in current:
            return
        setattr(
            item,
            "match_reason",
            f"{current} {addition}".strip() if current else addition,
        )

    def _existing_score(self, item: Any) -> int:
        for name in ("lead_score", "match_score"):
            value = getattr(item, name, 0)
            if isinstance(value, int):
                return value
        return 0

    def _field(self, item: Any, *names: str) -> str:
        for name in names:
            value = getattr(item, name, "")
            if value is None:
                continue
            if isinstance(value, str):
                return value
            if not isinstance(value, (list, tuple, set, dict)):
                return str(value)
        return ""

    def _field_list(self, item: Any, *names: str) -> list[str]:
        values: list[str] = []
        for name in names:
            value = getattr(item, name, [])
            if isinstance(value, (list, tuple, set)):
                values.extend(str(entry) for entry in value if entry)
            elif isinstance(value, str) and value:
                values.append(value)
        return values

    def _wants_remote(self, task: SearchTask, profile: Profile | None) -> bool:
        values = [*task.filters, task.location, *task.keywords]
        if profile is not None:
            values.extend(profile.preferred_job_types)
        return any("remote" in self._normalize(value) for value in values)

    def _looks_remote(self, item: Any) -> bool:
        values = [
            self._field(item, "location"),
            self._field(item, "remote_status"),
            self._field(item, "country"),
        ]
        return any("remote" in self._normalize(value) for value in values)

    def _wants_visa_or_relocation(self, task: SearchTask) -> bool:
        text = self._normalize(" ".join([*task.filters, *task.keywords, task.title]))
        return "visa" in text or "relocation" in text or "sponsorship" in text

    def _has_visa_or_relocation(self, item: Any) -> bool:
        values = [
            self._field(item, "visa_sponsorship_status"),
            self._field(item, "relocation_support_status"),
        ]
        return bool(getattr(item, "visa_sponsorship", False)) or any(
            "yes" in self._normalize(value) for value in values
        )

    def _contains(self, text: str, term: str) -> bool:
        normalized_term = self._normalize(term)
        if not normalized_term:
            return False
        return normalized_term in text

    @staticmethod
    def _normalize(value: str) -> str:
        return re.sub(r"\s+", " ", str(value).strip().casefold())
