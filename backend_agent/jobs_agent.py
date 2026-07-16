from __future__ import annotations

from .agent_base import BaseOpportunityAgent
from .models import Job, SearchTask
from .profile_match_engine import Profile
from .sources.base_source import FreshnessWindow
from .sources.base_source import SourceOpportunity
from .sources.jobs_sources import (
    finalize_private_job,
    is_suitable_private_job,
    job_sources,
    private_job_rank,
)


class JobsAgent(BaseOpportunityAgent[Job]):
    _templates = (
        {
            "title": "Junior AI/ML Engineer",
            "organization": "Nova Intelligence",
            "location": "Germany",
            "skills": ["Python", "Machine Learning", "Computer Vision"],
            "visa_sponsorship": True,
            "fresher_friendly": True,
            "training_provided": True,
        },
        {
            "title": "Flutter Developer",
            "organization": "Global Mobile Labs",
            "location": "Remote",
            "skills": ["Flutter", "Dart", "REST APIs"],
            "visa_sponsorship": False,
            "fresher_friendly": True,
            "training_provided": True,
        },
        {
            "title": "Computer Vision Associate",
            "organization": "Vision Systems Europe",
            "location": "Netherlands",
            "skills": ["YOLO", "Roboflow", "Python"],
            "visa_sponsorship": True,
            "fresher_friendly": True,
            "training_provided": False,
        },
    )

    def __init__(
        self,
        freshness: str = FreshnessWindow.LAST_7_DAYS,
    ) -> None:
        super().__init__(job_sources(), freshness)

    def execute(
        self,
        task: SearchTask,
        profile: Profile | None = None,
    ) -> list[Job]:
        source_items = self.collect_real(
            task,
            apply_limit=False,
            profile=profile,
        )
        for item in source_items:
            finalize_private_job(item)
        source_items = [
            item for item in source_items if is_suitable_private_job(item)
        ]
        source_items.sort(key=private_job_rank)
        requires_visa = any(
            value in " ".join(task.filters).casefold()
            for value in ("visa", "relocation")
        )
        if requires_visa:
            sponsored = [
                item
                for item in source_items
                if item.visa_sponsorship_status == "Yes"
                or item.relocation_support_status == "Yes"
            ]
            pakistan = [
                item
                for item in source_items
                if "pakistan" in item.location.casefold()
            ]
            source_items = sponsored or pakistan or source_items
        source_items = self.personalization_service.rank_items(
            source_items,
            task,
            profile,
        )
        source_items = source_items[: task.daily_limit]
        real_results = [
            Job(**self.source_fields(item))
            for item in source_items
        ]
        if real_results:
            return real_results
        if not self.successful_sources:
            return self._mock_results(task)
        return []

    def _mock_results(self, task: SearchTask) -> list[Job]:
        posted_date, deadline = self.dates(deadline_days=30)
        results: list[Job] = []
        for index, template in enumerate(
            self._templates[: self.result_count(task, len(self._templates))]
        ):
            source = SourceOpportunity(
                    title=template["title"],
                    organization=template["organization"],
                    location=template["location"],
                    source_link=f"{self.source_base_url}/jobs/{task.id}/{index + 1}",
                    posted_date=posted_date,
                    deadline=deadline,
                    required_skills=self.task_skills(
                        task,
                        template["skills"],
                    ),
                    visa_sponsorship=template["visa_sponsorship"],
                    fresher_friendly=template["fresher_friendly"],
                    training_provided=template["training_provided"],
                    source_name="Mock fallback",
                    visa_sponsorship_status=(
                        "Yes" if template["visa_sponsorship"] else "No"
                    ),
                    relocation_support_status=(
                        "Yes" if template["visa_sponsorship"] else "Unknown"
                    ),
                    fresher_friendly_status="Yes",
                    training_provided_status=(
                        "Yes" if template["training_provided"] else "No"
                    ),
                    remote_status=(
                        "Yes"
                        if "remote" in template["location"].casefold()
                        else "No"
                    ),
                    match_reason=(
                        "Mock fallback matching the requested early-career "
                        "technology profile."
                    ),
                    cv_changes_needed=[
                        "Add measurable AI, computer vision, or Flutter project outcomes."
                    ],
                    is_mock=True,
                )
            results.append(Job(**self.source_fields(source)))
        return results
