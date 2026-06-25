from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

from .api_server import OpportunityApiServer
from .profile_match_engine import Profile
from .task_runner import TaskRunner
from .sources.base_source import FreshnessWindow

PACKAGE_DIRECTORY = Path(__file__).resolve().parent
DEFAULT_DATA_DIRECTORY = PACKAGE_DIRECTORY / "data"
DEFAULT_TASKS_PATH = DEFAULT_DATA_DIRECTORY / "search_tasks.json"
DEFAULT_PROFILE_PATH = DEFAULT_DATA_DIRECTORY / "profile.json"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run active Career Client Agent search tasks.",
    )
    parser.add_argument(
        "--tasks",
        type=Path,
        default=DEFAULT_TASKS_PATH,
        help="Path to a JSON file containing search tasks.",
    )
    parser.add_argument(
        "--profile",
        type=Path,
        default=DEFAULT_PROFILE_PATH,
        help="Path to a JSON profile used for match scoring.",
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=DEFAULT_DATA_DIRECTORY,
        help="Directory where categorized JSON results are written.",
    )
    parser.add_argument(
        "--freshness",
        choices=FreshnessWindow.VALUES,
        default=FreshnessWindow.LAST_7_DAYS,
        help="Keep results from today, the last 24 hours, or the last 7 days.",
    )
    parser.add_argument(
        "--serve",
        action="store_true",
        help="Serve generated opportunities over HTTP after running tasks.",
    )
    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="HTTP server host used with --serve.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="HTTP server port used with --serve.",
    )
    return parser


def load_profile(path: Path) -> Profile:
    if not path.exists():
        return Profile()
    with path.open("r", encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return Profile.from_dict(payload)


def main(arguments: Sequence[str] | None = None) -> int:
    options = build_parser().parse_args(arguments)
    runner = TaskRunner(
        data_directory=options.data_dir,
        profile=load_profile(options.profile),
        freshness=options.freshness,
    )
    output_paths = runner.run(options.tasks)

    if not output_paths:
        print("No active search tasks were found.")
        return 0

    print(f"Completed {len(output_paths)} active search task(s):")
    for output_path in output_paths:
        print(f"- {output_path}")

    if options.serve:
        OpportunityApiServer(
            data_directory=options.data_dir,
            host=options.host,
            port=options.port,
        ).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
