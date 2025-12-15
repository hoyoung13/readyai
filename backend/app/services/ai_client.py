from typing import Any, Dict, List

from fastapi import HTTPException, status
from openai import AsyncOpenAI

from app.config import get_settings
from app.schemas import (
    ActionableEdit,
    EvaluateRequest,
    EvaluateResponse,
    ProofreadComment,
    ProofreadRequest,
    ProofreadResponse,
    RubricScores,
    SummarizeRequest,
    SummarizeResponse,
)

settings = get_settings()


class AiClient:
    def __init__(self) -> None:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is required")
        self.client = AsyncOpenAI(api_key=settings.openai_api_key, base_url=settings.api_base_url)

    async def evaluate(self, payload: EvaluateRequest) -> EvaluateResponse:
        prompt = self._build_eval_prompt(payload)
        response = await self._chat(prompt)
        try:
            json_data = response if isinstance(response, dict) else response.model_dump()
        except Exception as exc:  # pragma: no cover - defensive
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI 응답을 파싱하지 못했습니다.",
            ) from exc
        return EvaluateResponse(**json_data)

    async def summarize(self, payload: SummarizeRequest) -> SummarizeResponse:
        prompt = (
            "다음 이력서 내용을 간결하게 요약해 주세요. 불릿 5개 이내, 한줄 요약, 핵심 키워드 8개 이내로 반환합니다."
            f"\n언어: {payload.language}\n본문:\n{payload.extractedText}"
        )
        result = await self._chat(prompt, response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "resume_summary",
                "schema": {
                    "type": "object",
                    "properties": {
                        "bulletSummary": {"type": "array", "items": {"type": "string"}},
                        "oneLiner": {"type": "string"},
                        "keywords": {"type": "array", "items": {"type": "string"}},
                    },
                    "required": ["bulletSummary", "oneLiner", "keywords"],
                    "additionalProperties": False,
                },
            },
        })
        payload = result if isinstance(result, dict) else result.model_dump()
        return SummarizeResponse(**payload)

    async def proofread(self, payload: ProofreadRequest) -> ProofreadResponse:
        prompt = (
            "주어진 자기소개서 내용을 사실을 추가하지 않고 문법적으로 교정하고, 개선 의견을 제공합니다."
            "각 개선 의견은 줄 또는 섹션 기준으로 작성해 주세요."
            f"\n목표 직무: {payload.targetRole or '미지정'}\n언어: {payload.language}\n본문:\n{payload.extractedText}"
        )
        result = await self._chat(prompt, response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "proofread_response",
                "schema": {
                    "type": "object",
                    "properties": {
                        "correctedText": {"type": "string"},
                        "comments": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "lineOrSection": {"type": "string"},
                                    "comment": {"type": "string"},
                                },
                                "required": ["lineOrSection", "comment"],
                                "additionalProperties": False,
                            },
                        },
                    },
                    "required": ["correctedText", "comments"],
                    "additionalProperties": False,
                },
            },
        })
        payload = result if isinstance(result, dict) else result.model_dump()
        return ProofreadResponse(**payload)

    async def _chat(self, prompt: str, response_format: Dict[str, Any] | None = None):
        try:
            completion = await self.client.responses.create(
                model=settings.openai_model,
                input=prompt,
                response_format=response_format
                or {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "evaluation_report",
                        "schema": self._evaluation_schema(),
                    },
                },
            )
            return completion.output_parsed
        except Exception as exc:  # pragma: no cover - API failures
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="OpenAI 요청이 실패했습니다.",
            ) from exc

    def _build_eval_prompt(self, payload: EvaluateRequest) -> str:
        base = (
            "주어진 문서 내용을 기반으로 평가합니다."
            "허구의 경험, 회사, 수상 이력, 날짜를 새로 만들지 말고 원문 사실만 재구성합니다."
            "점수는 0-100 사이 정수로 제공하고, 개선본은 한국어로 작성합니다."
            f"\n문서 유형: {payload.docKind}\n언어: {payload.language}\n목표 직무: {payload.targetRole or '미지정'}"
            "\n본문:\n" + payload.extractedText
        )
        return base

    def _evaluation_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "report": {
                    "type": "object",
                    "properties": {
                        "overallScore": {"type": "integer"},
                        "rubricScores": {
                            "type": "object",
                            "properties": {
                                "readability": {"type": "integer"},
                                "impact": {"type": "integer"},
                                "structure": {"type": "integer"},
                                "specificity": {"type": "integer"},
                                "roleFit": {"type": "integer"},
                            },
                            "required": [
                                "readability",
                                "impact",
                                "structure",
                                "specificity",
                                "roleFit",
                            ],
                        },
                        "strengths": {"type": "array", "items": {"type": "string"}},
                        "weaknesses": {"type": "array", "items": {"type": "string"}},
                        "actionableEdits": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "section": {"type": "string"},
                                    "issue": {"type": "string"},
                                    "suggestion": {"type": "string"},
                                },
                                "required": ["section", "issue", "suggestion"],
                                "additionalProperties": False,
                            },
                        },
                        "redFlags": {"type": "array", "items": {"type": "string"}},
                        "summary": {"type": "string"},
                    },
                    "required": [
                        "overallScore",
                        "rubricScores",
                        "strengths",
                        "weaknesses",
                        "actionableEdits",
                        "redFlags",
                        "summary",
                    ],
                },
                "improvedVersion": {"type": "string"},
            },
            "required": ["report", "improvedVersion"],
            "additionalProperties": False,
        }