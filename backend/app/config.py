import os
from functools import lru_cache


class Settings:
    openai_api_key: str
    openai_model: str
    firebase_bucket: str | None
    max_text_length: int = 200_000

    def __init__(self) -> None:
        self.openai_api_key = os.getenv("OPENAI_API_KEY", "")
        self.openai_model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
        self.firebase_bucket = os.getenv("FIREBASE_BUCKET")

    @property
    def api_base_url(self) -> str:
        return os.getenv("OPENAI_BASE_URL", "") or "https://api.openai.com/v1"


@lru_cache()
def get_settings() -> Settings:
    return Settings()