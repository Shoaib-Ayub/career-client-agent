from __future__ import annotations

from .rss_source import RssSource

GOOGLE_NEWS_RSS = (
    "https://news.google.com/rss/search?q={query}"
    "&hl=en-US&gl=US&ceid=US:en"
)


def scholarship_sources() -> list[RssSource]:
    return [
        RssSource(
            source_name="Google News Scholarships",
            query_template=GOOGLE_NEWS_RSS,
            default_location="Worldwide",
            query_prefix='"scholarship" OR "fellowship" OR "fully funded"',
            required_terms=(
                "scholarship",
                "fellowship",
                "students",
                "university",
                "master",
                "phd",
            ),
        )
    ]
