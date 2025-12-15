import re
from typing import Iterable


def clean_text(blocks: Iterable[str]) -> str:
    text = "\n".join(blocks)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"(\s{2,})", " ", text)
    text = text.replace("\u3000", " ").strip()
    return text


def strip_headers_and_footers(text: str) -> str:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return text
    if len(lines) < 6:
        return " \n".join(lines)
    first_line = lines[0]
    last_line = lines[-1]
    filtered = [line for line in lines if line not in {first_line, last_line}]
    return " \n".join(filtered) if filtered else " \n".join(lines)