from __future__ import annotations

from abc import abstractmethod
from typing import Any
from urllib.parse import urlencode

from .base_source import BaseSource, SourceCollectionError, SourceOpportunity
from ..models import SearchTask


class SearchSource(BaseSource):
    @abstractmethod
    def build_url(self, task: SearchTask) -> str:
        """Build the public search endpoint URL."""

    @abstractmethod
    def parse_payload(
        self,
        payload: Any,
        task: SearchTask,
    ) -> list[SourceOpportunity]:
        """Normalize a public search response."""

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        payload = self.fetch_json(self.build_url(task))
        try:
            return self.parse_payload(payload, task)
        except (KeyError, TypeError, ValueError) as error:
            raise SourceCollectionError(
                f"{self.source_name} returned an unsupported response."
            ) from error

    @staticmethod
    def url(base_url: str, parameters: dict[str, object]) -> str:
        return f"{base_url}?{urlencode(parameters)}"
