from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed

from .agent_base import BaseOpportunityAgent
from .models import ClientLead, SearchTask
from .profile_match_engine import Profile
from .sources.base_source import (
    FreshnessWindow,
    SourceOpportunity,
    deduplicate,
    filter_fresh,
    matches_task,
)
from .sources.client_leads_sources import client_leads_sources
from .services.client_lead_quality_service import ClientLeadQualityService


class ClientLeadsAgent(BaseOpportunityAgent[ClientLead]):
    max_source_workers = 4
    quality_service = ClientLeadQualityService()
    _templates = (
        {
            "title": "Flutter Mobile App with AI Features",
            "organization": "Retail Innovation Studio",
            "location": "Remote",
            "skills": ["Flutter", "Dart", "AI"],
        },
        {
            "title": "YOLO Object Detection Dashboard",
            "organization": "Smart Vision Commerce",
            "location": "Remote",
            "skills": ["YOLO", "Roboflow", "Computer Vision"],
        },
    )

    def __init__(
        self,
        freshness: str = FreshnessWindow.LAST_7_DAYS,
    ) -> None:
        super().__init__(client_leads_sources(), freshness)

    def execute(
        self,
        task: SearchTask,
        profile: Profile | None = None,
    ) -> list[ClientLead]:
        if any(value.casefold() == "github" for value in task.filters):
            self.sources = client_leads_sources(include_github=True)
        source_items = self.quality_service.deduplicate_leads(
            self._collect_sources_concurrently(task)
        )
        source_items = self.personalization_service.rank_items(
            source_items,
            task,
            profile,
            preserve_all=True,
        )[: task.daily_limit]
        real_results = [
            ClientLead(
                **self.source_fields(item),
                short_message=item.short_message,
                search_keyword=item.search_keyword,
                manual_action=item.manual_action,
                expected_lead_type=item.expected_lead_type,
                platform_project_id=item.platform_project_id,
                normalized_title=item.normalized_title,
                normalized_proposal_url=item.normalized_proposal_url,
                dedupe_key=item.dedupe_key,
            )
            for item in source_items
        ]
        if real_results:
            return real_results
        return self._mock_results(task)

    def _collect_sources_concurrently(
        self,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        self.failed_sources = []
        self.successful_sources = []
        self.source_reports = []
        indexed_results: dict[int, list[SourceOpportunity]] = {}

        worker_count = min(self.max_source_workers, max(1, len(self.sources)))
        with ThreadPoolExecutor(
            max_workers=worker_count,
            thread_name_prefix="client-lead-source",
        ) as executor:
            futures = {}
            for index, source in enumerate(self.sources):
                source.reset_status()
                futures[executor.submit(source.collect, task)] = (index, source)

            for future in as_completed(futures):
                index, source = futures[future]
                try:
                    indexed_results[index] = list(future.result())
                except Exception as error:
                    source.mark_degraded(str(error), fallback_used=False)
                    indexed_results[index] = []
                    print(f"Warning: {source.source_name} failed: {error}")

        collected: list[SourceOpportunity] = []
        for index, source in enumerate(self.sources):
            collected.extend(indexed_results.get(index, []))
            if source.last_status == "ok":
                self.successful_sources.append(source.source_name)
            else:
                self.failed_sources.append(source.source_name)
            self.source_reports.append(source.status_report())

        relevant = [item for item in collected if matches_task(item, task)]
        fresh = filter_fresh(relevant, self.freshness)
        return deduplicate(fresh)

    @staticmethod
    def _stable_rank_key(item: SourceOpportunity) -> tuple[object, ...]:
        return (
            -item.lead_score,
            item.platform.casefold(),
            item.title.casefold(),
        )

    def _mock_results(self, task: SearchTask) -> list[ClientLead]:
        posted_date, deadline = self.dates(deadline_days=14)
        results: list[ClientLead] = []
        for index, template in enumerate(
            self._templates[: self.result_count(task, len(self._templates))]
        ):
            results.append(
                ClientLead(
                    title=template["title"],
                    organization=template["organization"],
                    location=template["location"],
                    source_link=f"{self.source_base_url}/leads/{task.id}/{index + 1}",
                    posted_date=posted_date,
                    deadline=deadline,
                    skills=self.task_skills(task, template["skills"]),
                    visa_sponsorship=False,
                    fresher_friendly=False,
                    training_provided=False,
                    source_name="Mock fallback",
                    lead_category="Freelance Projects",
                    budget_type="Unknown",
                    country="Remote",
                    platform="Mock fallback",
                    proposal_url=(
                        f"{self.source_base_url}/leads/{task.id}/{index + 1}"
                    ),
                    lead_score=35,
                    why_good_lead=[
                        "Mock fallback for testing the client lead pipeline.",
                    ],
                    suggested_message=(
                        "Hello, I can help build this project and share a "
                        "clear plan, timeline, and relevant samples."
                    ),
                    short_message=(
                        "Hello, I can help with this Flutter and AI project. "
                        "Could we have a short chat about the requirements?"
                    ),
                )
            )
        return results
