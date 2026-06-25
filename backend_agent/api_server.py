from __future__ import annotations

import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


class OpportunityApiServer:
    ENDPOINTS = {
        "/api/jobs": "jobs",
        "/api/scholarships": "scholarships",
        "/api/government-jobs": "government_jobs",
        "/api/client-leads": "client_leads",
    }

    def __init__(
        self,
        data_directory: Path,
        host: str,
        port: int,
    ) -> None:
        self.data_directory = data_directory
        self.host = host
        self.port = port

    def serve_forever(self) -> None:
        handler = self._create_handler()
        server = ThreadingHTTPServer((self.host, self.port), handler)
        print(f"Backend API listening on http://{self.host}:{self.port}")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nStopping backend API.")
        finally:
            server.server_close()

    def _create_handler(self) -> type[BaseHTTPRequestHandler]:
        data_directory = self.data_directory
        endpoints = self.ENDPOINTS

        class RequestHandler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                path = urlparse(self.path).path
                category = endpoints.get(path)
                if category is None:
                    self._send_json(
                        HTTPStatus.NOT_FOUND,
                        {"error": "Endpoint not found."},
                    )
                    return

                results = _read_latest_results(data_directory / category)
                self._send_json(HTTPStatus.OK, {"data": results})

            def _send_json(
                self,
                status: HTTPStatus,
                payload: dict[str, Any],
            ) -> None:
                body = json.dumps(payload).encode("utf-8")
                self.send_response(status.value)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, format: str, *args: object) -> None:
                return

        return RequestHandler


def _read_latest_results(directory: Path) -> list[dict[str, Any]]:
    if not directory.exists():
        return []

    latest_by_task: dict[str, Path] = {}
    for path in directory.glob("*.json"):
        task_id = path.stem.rsplit("_", maxsplit=1)[0]
        previous = latest_by_task.get(task_id)
        if previous is None or path.stat().st_mtime > previous.stat().st_mtime:
            latest_by_task[task_id] = path

    results: list[dict[str, Any]] = []
    for path in sorted(latest_by_task.values()):
        with path.open("r", encoding="utf-8") as file:
            payload = json.load(file)
        if isinstance(payload, list):
            results.extend(item for item in payload if isinstance(item, dict))
    return results
