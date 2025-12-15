import time
from collections import defaultdict
from typing import DefaultDict

from fastapi import HTTPException, Request, status

RATE_LIMIT_SECONDS = 1.0


class RateLimiter:
    def __init__(self) -> None:
        self._last_called: DefaultDict[str, float] = defaultdict(float)

    def check(self, request: Request) -> None:
        client_ip = request.client.host if request.client else "anonymous"
        now = time.time()
        elapsed = now - self._last_called[client_ip]
        if elapsed < RATE_LIMIT_SECONDS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again shortly.",
            )
        self._last_called[client_ip] = now


_limiter = RateLimiter()


def get_rate_limiter() -> RateLimiter:
    return _limiter