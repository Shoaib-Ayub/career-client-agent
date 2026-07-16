from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date, timedelta
from typing import Generic, TypeVar

from .models import Opportunity, SearchTask
from .profile_match_engine import Profile
from .services.personalization_service import AgentPersonalizationService
from .sources.base_source import (
    BaseSource,
    FreshnessWindow,
    SourceOpportunity,
    deduplicate,
    filter_fresh,
    matches_task,
    sort_newest,
)

OpportunityT = TypeVar("OpportunityT", bound=Opportunity)


class BaseOpportunityAgent(ABC, Generic[OpportunityT]):
    source_base_url = "https://example.com"

    def __init__(
        self,
        sources: list[BaseSource] | None = None,
        freshness: str = FreshnessWindow.LAST_7_DAYS,
    ) -> None:
        self.sources = sources or []
        self.freshness = freshness
        self.failed_sources: list[str] = []
        self.successful_sources: list[str] = []
        self.source_reports: list[dict[str, object]] = []
        self.personalization_service = AgentPersonalizationService()

    @abstractmethod
    def execute(
        self,
        task: SearchTask,
        profile: Profile | None = None,
    ) -> list[OpportunityT]:
        """Collect results for a search task."""

    def collect_real(
        self,
        task: SearchTask,
        apply_limit: bool = True,
        profile: Profile | None = None,
        preserve_all: bool = False,
    ) -> list[SourceOpportunity]:
        collected: list[SourceOpportunity] = []
        self.failed_sources = []
        self.successful_sources = []
        self.source_reports = []
        for source in self.sources:
            source.reset_status()
            try:
                collected.extend(source.collect(task))
                if source.last_status == "ok":
                    self.successful_sources.append(source.source_name)
                else:
                    self.failed_sources.append(source.source_name)
            except Exception as error:
                source.mark_degraded(str(error), fallback_used=False)
                self.failed_sources.append(source.source_name)
                print(f"Warning: {source.source_name} failed: {error}")
            self.source_reports.append(source.status_report())

        relevant = [item for item in collected if matches_task(item, task)]
        fresh = filter_fresh(relevant, self.freshness)
        results = sort_newest(deduplicate(fresh))
        results = self.personalization_service.rank_items(
            results,
            task,
            profile,
            preserve_all=preserve_all,
        )
        return results[: task.daily_limit] if apply_limit else results

    @staticmethod
    def source_fields(item: SourceOpportunity) -> dict[str, object]:
        return {
            "title": item.title,
            "organization": item.organization,
            "location": item.location,
            "source_link": item.source_link,
            "posted_date": item.posted_date,
            "deadline": item.deadline,
            "skills": item.required_skills,
            "visa_sponsorship": item.visa_sponsorship,
            "fresher_friendly": item.fresher_friendly,
            "training_provided": item.training_provided,
            "source_name": item.source_name,
            "required_education": item.required_education,
            "eligibility_domicile": item.eligibility_domicile,
            "age_limit": item.age_limit,
            "advertisement_link": item.advertisement_link,
            "match_reason": item.match_reason,
            "bs_software_engineering_eligible": (
                item.bs_software_engineering_eligible
            ),
            "punjab_candidate_eligible": item.punjab_candidate_eligible,
            "is_mock": item.is_mock,
            "remote_status": item.remote_status,
            "salary": item.salary,
            "visa_sponsorship_status": item.visa_sponsorship_status,
            "relocation_support_status": item.relocation_support_status,
            "fresher_friendly_status": item.fresher_friendly_status,
            "training_provided_status": item.training_provided_status,
            "cv_changes_needed": item.cv_changes_needed,
            "force_category": item.force_category,
            "post_count": item.post_count,
            "job_scale": item.job_scale,
            "advertisement_number": item.advertisement_number,
            "is_source_review_link": item.is_source_review_link,
            "is_cached": item.is_cached,
            "cache_reason": item.cache_reason,
            "cached_from_run": item.cached_from_run,
            "source_status": item.source_status,
            "cache_warning": item.cache_warning,
            "lead_category": item.lead_category,
            "budget": item.budget,
            "budget_type": item.budget_type,
            "country": item.country,
            "platform": item.platform,
            "proposal_url": item.proposal_url,
            "lead_score": item.lead_score,
            "why_good_lead": item.why_good_lead,
            "suggested_message": item.suggested_message,
        }

    @staticmethod
    def result_count(task: SearchTask, available_templates: int) -> int:
        return min(task.daily_limit, available_templates)

    @staticmethod
    def dates(deadline_days: int) -> tuple[str, str]:
        today = date.today()
        return today.isoformat(), (today + timedelta(days=deadline_days)).isoformat()

    @staticmethod
    def task_skills(task: SearchTask, fallback: list[str]) -> list[str]:
        return task.keywords[:5] or fallback
