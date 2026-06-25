from __future__ import annotations

import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from backend_agent.publish_latest import publish_latest
from backend_agent.storage import JsonStorage


class PublishLatestTests(unittest.TestCase):
    def test_publishes_only_active_task_newest_generation(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            self._write_tasks(data_directory)
            storage = JsonStorage(data_directory)
            client_directory = data_directory / "client_leads"
            storage.write_json(
                client_directory
                / "default_client_leads_20260624T030000Z.json",
                [self._lead("Old Flutter project")],
            )
            storage.write_json(
                client_directory
                / "default_client_leads_20260624T040000Z.json",
                [self._lead("Newest Flutter project")],
            )
            storage.write_json(
                client_directory
                / "client_leads_qa_20260625T120000Z.json",
                [
                    {
                        "title": "Virtual Assistant needed",
                        "skills": ["Virtual Assistant"],
                    }
                ],
            )
            storage.write_json(
                client_directory
                / "archived_client_leads_20260626T120000Z.json",
                [
                    {
                        "title": "HR and Marketing assistant",
                        "skills": ["HR", "Marketing"],
                    }
                ],
            )

            publish_latest(data_directory)

            latest = json.loads(
                (client_directory / "latest.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(len(latest), 1)
            self.assertEqual(latest[0]["title"], "Newest Flutter project")

    def test_combines_active_tasks_from_same_latest_generation(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            self._write_tasks(data_directory)
            storage = JsonStorage(data_directory)
            jobs_directory = data_directory / "jobs"
            storage.write_json(
                jobs_directory / "default_ai_jobs_20260625T080000Z.json",
                [{"title": "AI Engineer"}],
            )
            storage.write_json(
                jobs_directory / "default_visa_jobs_20260625T080000Z.json",
                [{"title": "Flutter Engineer"}],
            )
            storage.write_json(
                jobs_directory / "jobs_qa_20260626T080000Z.json",
                [{"title": "QA should not publish"}],
            )

            publish_latest(data_directory)

            latest = json.loads(
                (jobs_directory / "latest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                {record["title"] for record in latest},
                {"AI Engineer", "Flutter Engineer"},
            )

    def test_refuses_unrelated_client_lead_skills(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            self._write_tasks(data_directory)
            JsonStorage(data_directory).write_json(
                data_directory
                / "client_leads"
                / "default_client_leads_20260625T080000Z.json",
                [
                    {
                        "title": "Flutter application support",
                        "source_link": (
                            "https://example.com/projects/flutter/app"
                        ),
                        "skills": ["Flutter", "Customer Support"],
                        "lead_category": "Flutter Client Project",
                    }
                ],
            )

            with self.assertRaisesRegex(
                ValueError,
                "unrelated skills",
            ):
                publish_latest(data_directory)

    def test_accepts_ai_acronym_in_real_lead_title(self) -> None:
        with TemporaryDirectory() as directory:
            data_directory = Path(directory)
            self._write_tasks(data_directory)
            JsonStorage(data_directory).write_json(
                data_directory
                / "client_leads"
                / "default_client_leads_20260625T080000Z.json",
                [
                    {
                        "title": "AI Developer for Engineering Drawings",
                        "source_link": (
                            "https://example.com/projects/ai/drawings"
                        ),
                        "skills": ["AI/ML"],
                        "lead_category": "AI/ML Project",
                    }
                ],
            )

            publish_latest(data_directory)

            latest = json.loads(
                (
                    data_directory / "client_leads" / "latest.json"
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(len(latest), 1)
            self.assertEqual(
                latest[0]["title"],
                "AI Developer for Engineering Drawings",
            )

    @staticmethod
    def _lead(title: str) -> dict[str, object]:
        return {
            "title": title,
            "source_link": "https://example.com/projects/flutter/app",
            "skills": ["Flutter Development"],
            "lead_category": "Flutter Client Project",
        }

    @staticmethod
    def _write_tasks(data_directory: Path) -> None:
        JsonStorage(data_directory).write_json(
            data_directory / "search_tasks.json",
            [
                {
                    "id": "default_ai_jobs",
                    "task_type": "job",
                    "is_active": True,
                },
                {
                    "id": "default_visa_jobs",
                    "task_type": "job",
                    "is_active": True,
                },
                {
                    "id": "default_ms_scholarships",
                    "task_type": "scholarship",
                    "is_active": True,
                },
                {
                    "id": "default_government_jobs",
                    "task_type": "governmentJob",
                    "is_active": True,
                },
                {
                    "id": "default_client_leads",
                    "task_type": "clientLead",
                    "is_active": True,
                },
                {
                    "id": "archived_client_leads",
                    "task_type": "clientLead",
                    "is_active": False,
                },
            ],
        )


if __name__ == "__main__":
    unittest.main()
