from __future__ import annotations

from urllib.parse import quote_plus
from xml.etree import ElementTree

from .base_source import (
    BaseSource,
    SourceCollectionError,
    SourceOpportunity,
    datetime_value,
    extract_deadline,
    infer_skills,
    plain_text,
)
from ..models import SearchTask


class RssSource(BaseSource):
    def __init__(
        self,
        source_name: str,
        query_template: str,
        default_location: str,
        query_prefix: str = "",
        required_terms: tuple[str, ...] = (),
    ) -> None:
        super().__init__(source_name)
        self.query_template = query_template
        self.default_location = default_location
        self.query_prefix = query_prefix
        self.required_terms = tuple(value.casefold() for value in required_terms)

    def collect(self, task: SearchTask) -> list[SourceOpportunity]:
        terms = [value for value in task.keywords[:4] if value.strip()]
        alternatives = " OR ".join(f'"{value}"' for value in terms)
        location = (
            ""
            if task.location.casefold() == "worldwide"
            else f'"{task.location}"'
        )
        query = " ".join(
            value
            for value in [self.query_prefix, alternatives, location]
            if value
        )
        url = self.query_template.format(query=quote_plus(query))
        try:
            root = ElementTree.fromstring(self.fetch_text(url))
        except ElementTree.ParseError as error:
            raise SourceCollectionError(
                f"{self.source_name} returned invalid RSS."
            ) from error

        results: list[SourceOpportunity] = []
        for item in root.findall(".//item"):
            title = plain_text(item.findtext("title"))
            link = plain_text(item.findtext("link"))
            description = plain_text(item.findtext("description"))
            if not title or not link:
                continue
            searchable = f"{title} {description}".casefold()
            if self.required_terms and not any(
                value in searchable for value in self.required_terms
            ):
                continue
            source_element = item.find("source")
            organization = (
                plain_text(source_element.text)
                if source_element is not None
                else self.source_name
            )
            results.append(
                SourceOpportunity(
                    title=title,
                    organization=organization or self.source_name,
                    location=task.location or self.default_location,
                    source_link=link,
                    posted_date=datetime_value(
                        item.findtext("pubDate") or item.findtext("date")
                    ),
                    deadline=extract_deadline(f"{title} {description}"),
                    required_skills=infer_skills(
                        f"{title} {description}",
                        task,
                    ),
                    source_name=self.source_name,
                    description=description,
                )
            )
        return results
