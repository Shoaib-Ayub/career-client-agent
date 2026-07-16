from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from .client_leads_agent import ClientLeadsAgent
from .government_jobs_agent import GovernmentJobsAgent
from .jobs_agent import JobsAgent
from .models import Opportunity, SearchTask, TaskType
from .profile_match_engine import Profile, ProfileMatchEngine
from .scholarships_agent import ScholarshipsAgent
from .storage import JsonStorage
from .sources.base_source import FreshnessWindow
from .sources.base_source import freshness_status


class TaskRunner:
    CATEGORY_BY_TYPE = {
        TaskType.JOB: "jobs",
        TaskType.SCHOLARSHIP: "scholarships",
        TaskType.GOVERNMENT_JOB: "government_jobs",
        TaskType.CLIENT_LEAD: "client_leads",
    }

    def __init__(
        self,
        data_directory: Path,
        profile: Profile | None = None,
        freshness: str = FreshnessWindow.LAST_7_DAYS,
    ) -> None:
        self.storage = JsonStorage(data_directory)
        self.profile = (profile or Profile()).or_default()
        self.match_engine = ProfileMatchEngine()
        self.agents = {
            TaskType.JOB: JobsAgent(freshness),
            TaskType.SCHOLARSHIP: ScholarshipsAgent(freshness),
            TaskType.GOVERNMENT_JOB: GovernmentJobsAgent(
                freshness,
                cache_directory=data_directory / "government_jobs",
                snapshot_directory=(
                    data_directory / "cache" / "government_jobs"
                ),
            ),
            TaskType.CLIENT_LEAD: ClientLeadsAgent(freshness),
        }

    def load_tasks(self, tasks_path: Path) -> list[SearchTask]:
        tasks = [
            SearchTask.from_dict(payload)
            for payload in self.storage.read_list(tasks_path)
        ]
        return tasks or self.default_tasks()

    @staticmethod
    def default_tasks() -> list[SearchTask]:
        created_at = "2026-06-19"
        return [
            SearchTask(
                id="default_ai_jobs",
                title="AI/ML & Computer Vision Fresher Jobs",
                task_type=TaskType.JOB,
                keywords=[
                    "AI",
                    "Machine Learning",
                    "Computer Vision",
                    "Python",
                    "YOLO",
                    "Flutter Developer",
                    "Junior Software Engineer",
                    "Associate Software Engineer",
                ],
                location="Worldwide",
                level="Fresher",
                filters=["Entry Level", "Full-time"],
                daily_limit=10,
                is_active=True,
                created_at=created_at,
            ),
            SearchTask(
                id="default_visa_jobs",
                title="Visa Sponsorship & Relocation Jobs",
                task_type=TaskType.JOB,
                keywords=[
                    "Visa Sponsorship",
                    "Relocation",
                    "Flutter",
                    "AI",
                    "Machine Learning Engineer",
                    "Computer Vision Engineer",
                    "Junior Software Engineer",
                ],
                location="Worldwide",
                level="International",
                filters=["Visa Sponsorship", "Relocation Assistance"],
                daily_limit=5,
                is_active=True,
                created_at=created_at,
            ),
            SearchTask(
                id="default_ms_scholarships",
                title="Fully Funded MS Scholarships with Stipend",
                task_type=TaskType.SCHOLARSHIP,
                keywords=[
                    "Fully Funded",
                    "MS",
                    "Artificial Intelligence",
                    "Machine Learning",
                    "Computer Vision",
                    "Stipend",
                ],
                location="Worldwide",
                level="MS",
                filters=["Monthly Stipend", "International Student"],
                daily_limit=10,
                is_active=True,
                created_at=created_at,
            ),
            SearchTask(
                id="default_government_jobs",
                title="Bachelor-Level Pakistan & Punjab Government Jobs",
                task_type=TaskType.GOVERNMENT_JOB,
                keywords=[
                    "Assistant",
                    "Officer",
                    "Inspector",
                    "Assistant Director",
                    "Lecturer",
                    "BS-16",
                    "BS-17",
                    "Bachelor",
                    "Graduation",
                    "16 years education",
                    "Punjab domicile",
                    "Open merit",
                    "All Pakistan",
                ],
                location="Pakistan, Punjab",
                level="Bachelor / Graduation / 16 years education",
                filters=[
                    "PPSC",
                    "FPSC",
                    "Punjab Job Portal",
                    "National Job Portal",
                    "Government",
                ],
                daily_limit=200,
                is_active=True,
                created_at=created_at,
            ),
            SearchTask(
                id="default_client_leads",
                title="CV-Matched Paid Client Projects",
                task_type=TaskType.CLIENT_LEAD,
                keywords=[
                    "Flutter Development",
                    "Flutter Firebase",
                    "Flutter AI Integration",
                    "Mobile AI App",
                    "AI ML",
                    "Computer Vision",
                    "YOLO Object Detection",
                    "TensorFlow Lite",
                    "TFLite",
                ],
                location="Remote",
                level="Professional",
                filters=[
                    "Flutter Client Project",
                    "Mobile AI Project",
                    "Computer Vision Project",
                    "AI/ML Project",
                    "TFLite / YOLO Project",
                    "Freelance",
                    "Remote",
                ],
                daily_limit=5,
                is_active=True,
                created_at=created_at,
            ),
        ]

    def run(self, tasks_path: Path) -> list[Path]:
        tasks = self.load_tasks(tasks_path)
        active_tasks = [task for task in tasks if task.is_active]
        output_paths: list[Path] = []
        run_time = datetime.now(timezone.utc)
        generation = run_time.strftime("%Y%m%dT%H%M%SZ")
        found_at = run_time.isoformat().replace("+00:00", "Z")
        totals = {category: 0 for category in self.CATEGORY_BY_TYPE.values()}
        failed_sources: set[str] = set()
        source_reports: dict[str, dict[str, object]] = {}
        government_diversity: dict[str, object] = {}
        government_snapshot_health: dict[str, dict[str, object]] = {}
        government_health_summary: dict[str, object] = {}

        for task in active_tasks:
            results = self._execute_task(task)
            if task.task_type == TaskType.GOVERNMENT_JOB:
                government_diversity = dict(
                    getattr(
                        self.agents[task.task_type],
                        "diversity_report",
                        {},
                    )
                )
                government_snapshot_health = dict(
                    getattr(
                        self.agents[task.task_type],
                        "snapshot_health_report",
                        {},
                    )
                )
                government_health_summary = dict(
                    getattr(
                        self.agents[task.task_type],
                        "health_summary",
                        {},
                    )
                )
            category = self.CATEGORY_BY_TYPE[task.task_type]
            totals[category] += len(results)
            failed_sources.update(self.agents[task.task_type].failed_sources)
            for report in self.agents[task.task_type].source_reports:
                if report["status"] != "ok":
                    source_reports[str(report["source_name"])] = report
            for result in results:
                result.found_at = found_at
                result.freshness_status = freshness_status(
                    result.posted_date,
                    now=run_time,
                )
            self.match_engine.apply(results, self.profile)
            output_paths.append(
                self.storage.write_results(
                    category=category,
                    task_id=task.id,
                    results=results,
                    timestamp=generation,
                )
            )
            task.last_run_at = datetime.now(timezone.utc).isoformat()

        self.storage.write_json(
            tasks_path,
            [task.to_dict() for task in tasks],
        )
        self.storage.write_json(
            self.storage.base_directory / "run_status.json",
            {
                "last_run_time": found_at,
                "total_jobs": totals["jobs"],
                "total_scholarships": totals["scholarships"],
                "total_government_jobs": totals["government_jobs"],
                "total_client_leads": totals["client_leads"],
                "failed_sources": sorted(failed_sources),
                "source_failures": [
                    source_reports[name] for name in sorted(source_reports)
                ],
                "government_jobs_diversity": government_diversity,
                "government_jobs_snapshot_health": (
                    government_snapshot_health
                ),
                "government_jobs_health_summary": (
                    government_health_summary
                ),
            },
        )
        return output_paths

    def _execute_task(self, task: SearchTask) -> list[Opportunity]:
        agent = self.agents[task.task_type]
        return list(agent.execute(task, self.profile))
