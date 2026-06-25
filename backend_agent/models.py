from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date
from enum import Enum
from typing import Any


class TaskType(str, Enum):
    JOB = "job"
    SCHOLARSHIP = "scholarship"
    GOVERNMENT_JOB = "governmentJob"
    CLIENT_LEAD = "clientLead"


@dataclass(slots=True)
class SearchTask:
    id: str
    title: str
    task_type: TaskType
    keywords: list[str]
    location: str
    level: str
    filters: list[str]
    daily_limit: int
    is_active: bool
    created_at: str
    last_run_at: str | None = None

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SearchTask":
        return cls(
            id=str(data["id"]),
            title=str(data["title"]),
            task_type=TaskType(data.get("task_type", data.get("taskType"))),
            keywords=[str(value) for value in data.get("keywords", [])],
            location=str(data.get("location", "Worldwide")),
            level=str(data.get("level", "Any")),
            filters=[str(value) for value in data.get("filters", [])],
            daily_limit=max(1, int(data.get("daily_limit", data.get("dailyLimit", 10)))),
            is_active=bool(data.get("is_active", data.get("isActive", True))),
            created_at=str(data.get("created_at", data.get("createdAt", date.today().isoformat()))),
            last_run_at=data.get("last_run_at", data.get("lastRunAt")),
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["task_type"] = self.task_type.value
        return payload


@dataclass(slots=True)
class Opportunity:
    title: str
    organization: str
    location: str
    source_link: str
    posted_date: str
    deadline: str
    match_score: int = 0
    skills: list[str] = field(default_factory=list)
    visa_sponsorship: bool = False
    fresher_friendly: bool = False
    training_provided: bool = False
    source_name: str = ""
    found_at: str = ""
    freshness_status: str = "unknown"
    required_education: str = ""
    eligibility_domicile: str = ""
    age_limit: str = ""
    advertisement_link: str = ""
    match_reason: str = ""
    bs_software_engineering_eligible: str = "Unknown"
    punjab_candidate_eligible: str = "Unknown"
    is_mock: bool = False
    remote_status: str = "Unknown"
    salary: str = ""
    visa_sponsorship_status: str = "Unknown"
    relocation_support_status: str = "Unknown"
    fresher_friendly_status: str = "Unknown"
    training_provided_status: str = "Unknown"
    cv_changes_needed: list[str] = field(default_factory=list)
    force_category: str = ""
    post_count: int | None = None
    job_scale: str = ""
    advertisement_number: str = ""
    is_source_review_link: bool = False
    is_cached: bool = False
    cache_reason: str = ""
    cached_from_run: str = ""
    source_status: str = "live"
    cache_warning: str = ""
    lead_category: str = ""
    budget: str = ""
    budget_type: str = "Unknown"
    country: str = ""
    platform: str = ""
    proposal_url: str = ""
    lead_score: int = 0
    why_good_lead: list[str] = field(default_factory=list)
    suggested_message: str = ""

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["required_skills"] = list(self.skills)
        return payload


@dataclass(slots=True)
class Job(Opportunity):
    def to_dict(self) -> dict[str, Any]:
        payload = Opportunity.to_dict(self)
        payload.update(
            {
                "company": self.organization,
                "country_city": self.location,
                "apply_link": self.source_link,
                "why_this_matches_me": self.match_reason,
            }
        )
        return payload


@dataclass(slots=True)
class Scholarship(Opportunity):
    pass


@dataclass(slots=True)
class GovernmentJob(Opportunity):
    def to_dict(self) -> dict[str, Any]:
        payload = Opportunity.to_dict(self)
        payload.update(
            {
                "department": self.organization,
                "province_city": self.location,
                "qualification": self.required_education,
                "qualification_required": self.required_education,
                "domicile_required": self.eligibility_domicile,
                "province_eligibility": self.punjab_candidate_eligible,
                "force_category": self.force_category,
                "application_deadline": self.deadline,
                "apply_link": self.source_link,
                "apply_url": self.source_link,
                "source": self.source_name,
                "eligibility_reason": self.match_reason,
                "post_count": self.post_count,
                "job_scale": self.job_scale,
                "advertisement_number": self.advertisement_number,
                "is_source_review_link": self.is_source_review_link,
                "is_cached": self.is_cached,
                "cache_reason": self.cache_reason,
                "cached_from_run": self.cached_from_run,
                "source_status": self.source_status,
                "cache_warning": self.cache_warning,
            }
        )
        return payload


@dataclass(slots=True)
class ClientLead(Opportunity):
    short_message: str = ""
    search_keyword: str = ""
    manual_action: str = ""
    expected_lead_type: str = ""
    platform_project_id: str = ""
    normalized_title: str = ""
    normalized_proposal_url: str = ""
    dedupe_key: str = ""

    def to_dict(self) -> dict[str, Any]:
        payload = Opportunity.to_dict(self)
        payload.update(
            {
                "client_platform": self.platform,
                "client_country": self.country,
                "apply_link": self.proposal_url or self.source_link,
                "why_this_is_good": list(self.why_good_lead),
            }
        )
        return payload
