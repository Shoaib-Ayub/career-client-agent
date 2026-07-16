from __future__ import annotations

import unittest

from backend_agent.models import SearchTask, TaskType
from backend_agent.profile_match_engine import Profile
from backend_agent.services.personalization_service import (
    AgentPersonalizationService,
)
from backend_agent.sources.base_source import SourceOpportunity


class AgentPersonalizationServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.service = AgentPersonalizationService()

    def test_profile_skills_rank_matching_result_first(self) -> None:
        task = self._task(keywords=[])
        profile = Profile(skills=["Flutter", "Firebase"])
        results = self.service.rank_items(
            [
                self._item("Marketing Assistant", "Marketing"),
                self._item(
                    "Flutter Firebase Mobile App",
                    "Flutter Firebase Dart",
                ),
            ],
            task,
            profile,
        )

        self.assertEqual("Flutter Firebase Mobile App", results[0].title)

    def test_task_keywords_rank_matching_result_first(self) -> None:
        task = self._task(keywords=["Computer Vision", "YOLO"])
        results = self.service.rank_items(
            [
                self._item("General Software Trainee", "Java support"),
                self._item(
                    "YOLO Object Detection App",
                    "Computer Vision YOLO TFLite",
                ),
            ],
            task,
            Profile(),
        )

        self.assertEqual("YOLO Object Detection App", results[0].title)

    def test_daily_limit_can_keep_best_matching_result(self) -> None:
        task = self._task(keywords=["Flutter"], daily_limit=1)
        ranked = self.service.rank_items(
            [
                self._item("Data Entry Operator", "Typing"),
                self._item("Flutter Developer", "Flutter Dart"),
            ],
            task,
            Profile(skills=["Flutter"]),
        )

        self.assertEqual(["Flutter Developer"], [item.title for item in ranked[: task.daily_limit]])

    def test_no_profile_or_task_keeps_original_order(self) -> None:
        task = self._task(keywords=[], location="", level="", filters=[])
        results = self.service.rank_items(
            [
                self._item("First Result", ""),
                self._item("Second Result", ""),
            ],
            task,
            Profile(),
        )

        self.assertEqual(["First Result", "Second Result"], [item.title for item in results])

    def test_government_jobs_can_be_preserved_for_broad_eligibility(self) -> None:
        task = self._task(
            task_type=TaskType.GOVERNMENT_JOB,
            keywords=["Assistant Director"],
        )
        results = self.service.rank_items(
            [
                self._item(
                    "Assistant Director",
                    "Bachelor degree Punjab domicile",
                ),
                self._item(
                    "Accounts Officer",
                    "Graduation open merit",
                ),
            ],
            task,
            Profile(skills=["Flutter"]),
            preserve_all=True,
        )

        self.assertEqual(2, len(results))
        self.assertEqual("Assistant Director", results[0].title)

    def _task(
        self,
        *,
        task_type: TaskType = TaskType.JOB,
        keywords: list[str],
        location: str = "Remote",
        level: str = "Entry Level",
        filters: list[str] | None = None,
        daily_limit: int = 10,
    ) -> SearchTask:
        return SearchTask(
            id="test-task",
            title="Test Task",
            task_type=task_type,
            keywords=keywords,
            location=location,
            level=level,
            filters=filters or [],
            daily_limit=daily_limit,
            is_active=True,
            created_at="2026-01-01",
        )

    def _item(self, title: str, description: str) -> SourceOpportunity:
        return SourceOpportunity(
            title=title,
            organization="Test Organization",
            location="Remote",
            source_link=f"https://example.com/{title.replace(' ', '-').lower()}",
            description=description,
            required_skills=description.split(),
            posted_date="2026-01-01",
            deadline="2026-12-31",
        )


if __name__ == "__main__":
    unittest.main()
