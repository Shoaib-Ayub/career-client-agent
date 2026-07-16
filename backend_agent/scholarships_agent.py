from __future__ import annotations

from .agent_base import BaseOpportunityAgent
from .models import Scholarship, SearchTask
from .profile_match_engine import Profile
from .sources.base_source import FreshnessWindow
from .sources.scholarship_sources import scholarship_sources


class ScholarshipsAgent(BaseOpportunityAgent[Scholarship]):
    _templates = (
        {
            "title": "Fully Funded MS in Artificial Intelligence",
            "organization": "European Technology University",
            "location": "Germany",
            "skills": ["Artificial Intelligence", "Research", "Python"],
        },
        {
            "title": "Computer Vision Masters Scholarship",
            "organization": "Future Vision Institute",
            "location": "United Kingdom",
            "skills": ["Computer Vision", "Machine Learning", "Research"],
        },
    )

    def __init__(
        self,
        freshness: str = FreshnessWindow.LAST_7_DAYS,
    ) -> None:
        super().__init__(scholarship_sources(), freshness)

    def execute(
        self,
        task: SearchTask,
        profile: Profile | None = None,
    ) -> list[Scholarship]:
        real_results = [
            Scholarship(**self.source_fields(item))
            for item in self.collect_real(task, profile=profile)
        ]
        if real_results:
            return real_results
        return self._mock_results(task)

    def _mock_results(self, task: SearchTask) -> list[Scholarship]:
        posted_date, deadline = self.dates(deadline_days=60)
        results: list[Scholarship] = []
        for index, template in enumerate(
            self._templates[: self.result_count(task, len(self._templates))]
        ):
            results.append(
                Scholarship(
                    title=template["title"],
                    organization=template["organization"],
                    location=template["location"],
                    source_link=(
                        f"{self.source_base_url}/scholarships/{task.id}/{index + 1}"
                    ),
                    posted_date=posted_date,
                    deadline=deadline,
                    skills=self.task_skills(task, template["skills"]),
                    visa_sponsorship=True,
                    fresher_friendly=True,
                    training_provided=True,
                    source_name="Mock fallback",
                )
            )
        return results
