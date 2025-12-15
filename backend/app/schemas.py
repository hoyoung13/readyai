from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, HttpUrl


class ProcessRequest(BaseModel):
    fileUrl: HttpUrl | str
    fileType: str = Field(pattern="^(pdf|hwp)$")
    docKind: str = Field(pattern="^(resume|coverLetter)$")
    language: str = Field(pattern="^(ko|en)$")
    targetRole: Optional[str] = None


class ProcessedDocument(BaseModel):
    extractedText: str
    pageCount: int
    pdfUrl: Optional[str] = None


class EvaluateRequest(BaseModel):
    extractedText: str
    docKind: str = Field(pattern="^(resume|coverLetter)$")
    language: str = Field(pattern="^(ko|en)$")
    targetRole: Optional[str] = None


class ActionableEdit(BaseModel):
    section: str
    issue: str
    suggestion: str


class RubricScores(BaseModel):
    readability: int
    impact: int
    structure: int
    specificity: int
    roleFit: int


class EvaluationReport(BaseModel):
    overallScore: int
    rubricScores: RubricScores
    strengths: List[str]
    weaknesses: List[str]
    actionableEdits: List[ActionableEdit]
    redFlags: List[str]
    summary: str


class EvaluateResponse(BaseModel):
    report: EvaluationReport
    improvedVersion: str


class SummarizeRequest(BaseModel):
    extractedText: str
    language: str = Field(pattern="^(ko|en)$")


class SummarizeResponse(BaseModel):
    bulletSummary: List[str]
    oneLiner: str
    keywords: List[str]


class ProofreadRequest(BaseModel):
    extractedText: str
    language: str = Field(pattern="^(ko|en)$")
    targetRole: Optional[str] = None


class ProofreadComment(BaseModel):
    lineOrSection: str
    comment: str


class ProofreadResponse(BaseModel):
    correctedText: str
    comments: List[ProofreadComment]


class ErrorResponse(BaseModel):
    detail: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)