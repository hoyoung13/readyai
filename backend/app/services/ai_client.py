import json
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
        response_text = await self._chat(prompt)

        try:
            json_data = json.loads(response_text)
        except Exception as exc:
            print("AI RAW RESPONSE ↓↓↓")
            print(response_text)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI 응답을 JSON으로 파싱하지 못했습니다.",
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

    async def _chat(self, prompt: str):
        try:
            completion = await self.client.responses.create(
                model=settings.openai_model,
                input=(
                    prompt
                    + "\n\n반드시 JSON 형식으로만 응답하세요. "
                      "설명 문장이나 마크다운 없이 JSON만 출력하세요."
                ),
            )

            # SDK 버전에 따라 둘 중 하나가 맞음
            if hasattr(completion, "output_text") and completion.output_text:
                return completion.output_text

            return completion.output[0].content[0].text

        except Exception as exc:
            print("OPENAI ERROR:", exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=str(exc),
            ) from exc

    def _build_eval_prompt(self, payload: EvaluateRequest) -> str:
        return f"""
            너는 이력서 평가 AI다.
            아래 문서를 분석해서 반드시 **지정된 JSON 스키마 그대로**만 응답해야 한다.

            ❗ 규칙
            - JSON 이외의 텍스트, 설명, 마크다운, 코드블록 금지
            - 모든 필드는 반드시 포함
            - 한국어로 작성
            - 허구의 정보 추가 금지

            ❗ 반드시 아래 구조를 그대로 사용할 것:

            {{
            "report": {{
                "overallScore": 0-100 정수,
                "rubricScores": {{
                "readability": 0-100,
                "impact": 0-100,
                "structure": 0-100,
                "specificity": 0-100,
                "roleFit": 0-100
                }},
                "strengths": [문자열 배열],
                "weaknesses": [문자열 배열],
                "actionableEdits": [
                 {{
                    "section": "섹션명",
                    "issue": "문제점",
                    "suggestion": "개선 제안"
                }}
                ],
                "redFlags": [문자열 배열],
                "summary": "요약"
            }},
            "improvedVersion": "개선된 전체 문서"
            }}

            문서 유형: {payload.docKind}
            언어: {payload.language}
            목표 직무: {payload.targetRole or "미지정"}

            문서 내용:
            {payload.extractedText}
        """

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

        