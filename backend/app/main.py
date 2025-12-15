import logging
from typing import Annotated

from fastapi import Body, Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.rate_limit import RateLimiter, get_rate_limiter
from app.schemas import (
    ErrorResponse,
    EvaluateRequest,
    EvaluateResponse,
    ProcessRequest,
    ProcessedDocument,
    ProofreadRequest,
    ProofreadResponse,
    SummarizeRequest,
    SummarizeResponse,
)
from app.services.ai_client import AiClient
from app.services.document_processor import DocumentProcessor

logger = logging.getLogger(__name__)

settings = get_settings()
app = FastAPI(title="Resume AI Service")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def limit_body_size(request: Request, call_next):
    max_size = settings.max_text_length * 10
    if request.headers.get("content-length"):
        if int(request.headers["content-length"]) > max_size:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Payload too large",
            )
    return await call_next(request)


def get_processor() -> DocumentProcessor:
    return DocumentProcessor(firebase_bucket=settings.firebase_bucket)


def get_ai_client() -> AiClient:
    return AiClient()


@app.post("/api/document/process", response_model=ProcessedDocument, responses={400: {"model": ErrorResponse}})
async def process_document(
    payload: Annotated[ProcessRequest, Body(...)],
    request: Request,
    processor: DocumentProcessor = Depends(get_processor),
    limiter: RateLimiter = Depends(get_rate_limiter),
):
    limiter.check(request)
    return await processor.process(payload.fileUrl, payload.fileType)


@app.post("/api/ai/evaluate", response_model=EvaluateResponse, responses={502: {"model": ErrorResponse}})
async def evaluate(
    payload: Annotated[EvaluateRequest, Body(...)],
    request: Request,
    ai_client: AiClient = Depends(get_ai_client),
    limiter: RateLimiter = Depends(get_rate_limiter),
):
    limiter.check(request)
    if len(payload.extractedText) > settings.max_text_length:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="문서가 너무 큽니다.",
        )
    return await ai_client.evaluate(payload)


@app.post("/api/ai/summarize", response_model=SummarizeResponse, responses={502: {"model": ErrorResponse}})
async def summarize(
    payload: Annotated[SummarizeRequest, Body(...)],
    request: Request,
    ai_client: AiClient = Depends(get_ai_client),
    limiter: RateLimiter = Depends(get_rate_limiter),
):
    limiter.check(request)
    if len(payload.extractedText) > settings.max_text_length:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="문서가 너무 큽니다.",
        )
    return await ai_client.summarize(payload)


@app.post("/api/ai/proofread", response_model=ProofreadResponse, responses={502: {"model": ErrorResponse}})
async def proofread(
    payload: Annotated[ProofreadRequest, Body(...)],
    request: Request,
    ai_client: AiClient = Depends(get_ai_client),
    limiter: RateLimiter = Depends(get_rate_limiter),
):
    limiter.check(request)
    if len(payload.extractedText) > settings.max_text_length:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="문서가 너무 큽니다.",
        )
    return await ai_client.proofread(payload)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


__all__ = ["app"]