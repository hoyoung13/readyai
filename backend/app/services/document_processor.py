import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

import httpx
import pdfplumber
import pytesseract
from fastapi import HTTPException, status
from pdf2image import convert_from_path

from app.schemas import ProcessedDocument
from app.utils.text_utils import clean_text, strip_headers_and_footers


class DocumentProcessor:
    def __init__(self, firebase_bucket: Optional[str] = None) -> None:
        self.firebase_bucket = firebase_bucket

    async def download_file(self, url: str, suffix: str) -> Path:
        tmp_dir = Path(tempfile.mkdtemp())
        target = tmp_dir / f"source.{suffix}"
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.get(url)
        if response.status_code >= 400:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="문서를 다운로드하지 못했습니다.",
            )
        target.write_bytes(response.content)
        return target

    def convert_hwp_to_pdf(self, source_path: Path) -> Path:
        output_dir = source_path.parent
        try:
            subprocess.run(
                [
                    "libreoffice",
                    "--headless",
                    "--convert-to",
                    "pdf",
                    str(source_path),
                    "--outdir",
                    str(output_dir),
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="HWP 파일을 PDF로 변환할 수 없습니다.",
            ) from exc

        pdf_path = output_dir / f"{source_path.stem}.pdf"
        if not pdf_path.exists():
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="PDF 변환 결과를 찾을 수 없습니다.",
            )
        return pdf_path

    def extract_text_from_pdf(self, pdf_path: Path) -> tuple[str, int]:
        with pdfplumber.open(pdf_path) as pdf:
            pages = [page.extract_text() or "" for page in pdf.pages]
            page_count = len(pdf.pages)
        cleaned = clean_text(pages)
        cleaned = strip_headers_and_footers(cleaned)
        return cleaned, page_count

    def ocr_pdf(self, pdf_path: Path) -> str:
        images = convert_from_path(str(pdf_path), fmt="png")
        texts = [pytesseract.image_to_string(img, lang="kor+eng") for img in images]
        return clean_text(texts)

    async def process(self, url: str, file_type: str) -> ProcessedDocument:
        source_path: Path | None = None
        pdf_path: Path | None = None
        try:
            source_path = await self.download_file(url, file_type)
            pdf_path = source_path
            if file_type == "hwp":
                pdf_path = self.convert_hwp_to_pdf(source_path)

            text, page_count = self.extract_text_from_pdf(pdf_path)
            if len(text) < 300:
                text = self.ocr_pdf(pdf_path)

            text = text.strip()
            if not text:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="문서에서 텍스트를 추출하지 못했습니다.",
                )

            return ProcessedDocument(
                extractedText=text,
                pageCount=page_count,
                pdfUrl=None,
            )
        finally:
            if source_path is not None:
                try:
                    shutil.rmtree(source_path.parent)
                except Exception:
                    pass