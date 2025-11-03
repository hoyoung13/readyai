from __future__ import annotations

import json
import os
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

try:
  # requests 모듈은 HTTP 통신을 간편하게 만들어 준다.
  import requests
except ImportError as error:  # pragma: no cover - 환경에 따라 설치되지 않을 수 있다.
  requests = None  # type: ignore[assignment]
  IMPORT_ERROR = error
else:
  IMPORT_ERROR = None

API_ENDPOINT = "https://apis.data.go.kr/1051000/recruitment/list"
DETAIL_ENDPOINT = "https://apis.data.go.kr/1051000/recruitment/view"
DEFAULT_PARAMS = {
  "pageNo": "1",
  "numOfRows": "20",
  "type": "json",
}
# 다양한 응답 구조에서 채용 목록을 찾기 위해 미리 정의한 키 후보.
ITEM_KEYS = (
  "items",
  "list",
  "jobs",
  "data",
  "content",
  "result",
)

# 각 항목에서 추출할 필드별 키 후보 목록.
TITLE_KEYS = (
  "title",
  "job_title",
  "subject",
  "recruitmentTitle",
  "busiNm",
  "announcementTitle",
  "joTitle",
)
COMPANY_KEYS = (
  "company",
  "company_name",
  "companyName",
  "instNm",
  "organNm",
  "orgName",
  "publicInstitutionNm",
  "agency",
  "organization",
)
REGION_KEYS = (
  "region",
  "location",
  "area",
  "workPlcNm",
  "workRegion",
  "workRegionNm",
  "workLocation",
  "workPlace",
)
DATE_KEYS = (
  "date",
  "posted_date",
  "postedDate",
  "reg_date",
  "receiptCloseDt",
  "receiptEndDt",
  "rcptEdDt",
  "deadline",
  "applyEndDate",
)
URL_KEYS = (
  "url",
  "link",
  "detail_url",
  "detailUrl",
  "detailLink",
  "infoUrl",
  "homepageUrl",
  "recruitUrl",
  "applyUrl",
  "applyLink",
)

DETAIL_URL_KEYS = (
  "detailApiUrl",
  "detail_api_url",
  "detailApi",
  "detail_api",
  "detailViewUrl",
  "detailView",
  "detailPage",
  "detailPageUrl",
  "viewUrl",
  "detailServiceUrl",
)

# 상세 조회 응답에서 화면에 표시할 항목을 구성하기 위한 키 후보 매핑.
SUMMARY_FIELD_LABELS = {
  "모집분야": (
    "recruitField",
    "recruitmentField",
    "hireField",
    "position",
    "jobField",
    "field",
  ),
  "모집구분": (
    "recruitmentType",
    "employmentType",
    "hireType",
    "recruitmentCategory",
    "workType",
  ),
  "접수기간": (
    "receiptPeriod",
    "applyPeriod",
    "applyDate",
    "receiptBeginDt",
    "receiptCloseDt",
    "receiptStartEnd",
  ),
  "담당자": (
    "charger",
    "manager",
    "contactName",
    "chargePerson",
  ),
  "연락처": (
    "telNo",
    "managerTel",
    "contactTel",
    "managerPhone",
    "chargePhone",
  ),
  "이메일": (
    "email",
    "managerEmail",
    "contactEmail",
  ),
}

DETAIL_SECTION_LABELS = {
  "주요 업무": (
    "mainTask",
    "jobResponsibility",
    "mainDuty",
    "jobContent",
    "workContent",
  ),
  "자격 요건": (
    "qualification",
    "applyQualification",
    "eligible",
    "requirement",
    "requiredQualification",
  ),
  "우대 사항": (
    "preferential",
    "preference",
    "preferred",
    "advantage",
  ),
  "전형 절차": (
    "selectionProcess",
    "applyProcess",
    "process",
    "screeningProcess",
  ),
  "접수 방법": (
    "applyMethod",
    "applicationMethod",
    "receiptMethod",
  ),
  "제출 서류": (
    "requiredDocument",
    "submission",
    "submitDocument",
  ),
  "근무 조건": (
    "workCondition",
    "employmentCondition",
    "salary",
    "pay",
  ),
  "기타 안내": (
    "notice",
    "etc",
    "additional",
    "remark",
  ),
}


@dataclass
class JobCollectionResult:
  """채용 공고 수집 결과와 오류 여부를 함께 전달한다."""

  jobs: List[Dict[str, Any]]
  had_error: bool = False


def main() -> None:
  """프로그램의 진입점."""
  # 1) 프로젝트 루트와 JSON 파일 경로를 계산한다.
  base_dir = Path(__file__).resolve().parent.parent
  output_path = base_dir / "jobs.json"
  assets_path = base_dir / "assets" / "jobs.json"

  # 2) 실행 환경에서 사용할 서비스 키를 결정한다.
  service_key = _resolve_service_key()

  # 3) 채용공고를 수집하고 파일로 저장한 뒤 Flutter 자산으로 복사한다.
  result = _collect_jobs(service_key)
  jobs = result.jobs

  if result.had_error and not jobs:
    print("⚠️ 공공기관 공고를 불러오는 중 오류가 발생해 기존 데이터를 유지합니다.")
    return

  _write_jobs_file(output_path, jobs)
  _copy_to_assets(output_path, assets_path)

  # 4) 처리 결과를 사용자에게 알린다.
  message = f"✅ 총 {len(jobs)}개의 공공기관 공고 수집 완료 (Flutter assets로 저장됨)"
  if result.had_error:
    message += " — 일부 상세 정보를 불러오지 못했습니다."
  print(message)


def _resolve_service_key() -> str:
  """환경변수에서 서비스 키를 찾거나 예시 키를 사용한다."""
  env_key = os.getenv("PUBLIC_JOBS_SERVICE_KEY")
  if env_key:
    return env_key
  # 환경변수가 없다면 예시 키를 사용하고, 사용자에게 안내를 남긴다.
  example_key = (
    "kOGLQkaQcytpAB4RXIHgLVBEuRnUfEhCZGvgX%2BRn5LZWP1wYrVhtIsw5PPCGo8CLYTsjNckFxea00a%2FgOqrBSw%3D%3D"
  )
  print("[INFO] PUBLIC_JOBS_SERVICE_KEY 환경변수가 설정되지 않아 예시 인증키를 사용합니다.")
  return example_key


def _collect_jobs(service_key: str) -> JobCollectionResult:
  """채용공고를 조회하고 필요한 필드를 추출한다."""
  if requests is None:
    print(
      f"[ERROR] requests 모듈을 불러올 수 없습니다: {IMPORT_ERROR}. 'pip install requests'로 설치 후 다시 시도하세요."
    )
    return JobCollectionResult([], had_error=True)

  # 요청에 사용할 파라미터(페이지, 응답 형식 등)를 구성한다.
  params = {**DEFAULT_PARAMS, "serviceKey": service_key}
  try:
    # API 호출 (네트워크 타임아웃은 10초로 제한)
    response = requests.get(API_ENDPOINT, params=params, timeout=10)
    response.raise_for_status()
  except requests.RequestException as error:  # type: ignore[attr-defined]
    print(f"[ERROR] 채용공고 API 호출 중 오류가 발생했습니다: {error}")
    return JobCollectionResult([], had_error=True)

  try:
    # JSON 응답을 파싱한다.
    payload = response.json()
  except ValueError as error:
    print(f"[ERROR] 응답을 JSON으로 해석하는 데 실패했습니다: {error}")
    return JobCollectionResult([], had_error=True)

  # 응답 본문에서 실제 채용공고 목록을 찾아낸다.
  items = _extract_items(payload)
  jobs: List[Dict[str, Any]] = []
  had_error = False
  for raw_item in items:
    if not isinstance(raw_item, dict):
      continue
    job = {
      "title": _read_first(raw_item, TITLE_KEYS),
      "company": _read_first(raw_item, COMPANY_KEYS),
      "region": _read_first(raw_item, REGION_KEYS),
      "date": _read_first(raw_item, DATE_KEYS),
      "url": _read_first(raw_item, URL_KEYS),
    }

    detail_payload, detail_error = _fetch_detail_payload(raw_item, service_key)
    if detail_error:
      had_error = True
    if detail_payload:
      _merge_detail(job, detail_payload)
    else:
      _merge_detail(job, raw_item)

    if any(value for value in job.values()):
      jobs.append(job)

  return JobCollectionResult(jobs, had_error=had_error)


def _extract_items(node: Any) -> List[Any]:
  """응답 JSON에서 채용공고 목록으로 보이는 리스트를 추출한다."""
  if isinstance(node, list):
    return node

  if isinstance(node, dict):
    # 미리 정의한 키 후보부터 먼저 검사하여 리스트를 찾는다.
    for key in ITEM_KEYS:
      if key in node:
        items = _extract_items(node[key])
        if items:
          return items
    # 키 후보에서 찾지 못하면 모든 값에 대해 재귀적으로 탐색한다.
    for value in node.values():
      items = _extract_items(value)
      if items:
        return items

  return []


def _read_first(data: Dict[str, Any], keys: Iterable[str]) -> str:
  """키 후보들을 순회하며 처음 발견한 값을 문자열로 반환한다."""
  for key in keys:
    value = data.get(key)
    if value is None:
      continue
    text = str(value).strip()
    if text:
      return text
  return ""


def _fetch_detail_payload(raw_item: Dict[str, Any], service_key: str) -> Tuple[Dict[str, Any], bool]:
  """상세조회 API를 호출하여 추가 정보를 불러온다."""
  detail_url = _read_first(raw_item, DETAIL_URL_KEYS)
  if not detail_url:
    return {}, False

  if detail_url.startswith("http"):
    url = detail_url
    params: Dict[str, Any] | None = None
    if "serviceKey" not in detail_url:
      params = {"serviceKey": service_key}
  else:
    url = DETAIL_ENDPOINT
    params = {key: value for key, value in raw_item.items() if _is_scalar(value)}
    params["serviceKey"] = service_key
    if detail_url:
      params.setdefault("detailKey", detail_url)

  try:
    response = requests.get(url, params=params, timeout=10)  # type: ignore[attr-defined]
    response.raise_for_status()
  except requests.RequestException as error:  # type: ignore[attr-defined]
    print(f"[WARN] 상세 조회 호출에 실패했습니다: {error}")
    return {}, True

  try:
    payload = response.json()
  except ValueError:
    return {}, True

  if isinstance(payload, dict):
    return payload, False
  if isinstance(payload, list) and payload and isinstance(payload[0], dict):
    return payload[0], False
  return {}, True


def _merge_detail(job: Dict[str, Any], detail_payload: Dict[str, Any]) -> None:
  """상세 응답에서 요약 및 설명 정보를 추출한다."""
  summary_items = []
  for label, keys in SUMMARY_FIELD_LABELS.items():
    value = _read_first(detail_payload, keys)
    if value:
      summary_items.append({"label": label, "value": value})

  detail_rows = []
  for title, keys in DETAIL_SECTION_LABELS.items():
    description = _read_first(detail_payload, keys)
    if description:
      detail_rows.append({"title": title, "description": description})

  if not detail_rows:
    detail_rows = _fallback_detail_rows(detail_payload)

  if summary_items:
    job["summaryItems"] = summary_items
  if detail_rows:
    job["detailRows"] = detail_rows

  description = _read_first(
    detail_payload,
    (
      "description",
      "content",
      "jobDescription",
      "mainContent",
      "workDescription",
    ),
  )
  if description:
    job["description"] = description

  notice = _read_first(
    detail_payload,
    (
      "notice",
      "etc",
      "additional",
      "remark",
      "precaution",
    ),
  )
  if notice:
    job["notice"] = notice


def _fallback_detail_rows(detail_payload: Dict[str, Any]) -> List[Dict[str, str]]:
  """정의된 키에 걸리지 않은 경우 잔여 정보를 표로 보여준다."""
  rows: List[Dict[str, str]] = []
  for key, value in detail_payload.items():
    if isinstance(value, (list, dict)):
      text = json.dumps(value, ensure_ascii=False, indent=2)
    else:
      text = str(value).strip()
    if not text:
      continue
    rows.append({"title": _prettify_label(key), "description": text})
  return rows


def _prettify_label(key: str) -> str:
  """스네이크/카멜 형태의 키를 보기 좋은 문자열로 변환한다."""
  sanitized = key.replace("_", " ")
  sanitized = _camel_to_words(sanitized)
  text = sanitized.strip().capitalize()
  return text if text else key


def _camel_to_words(text: str) -> str:
  result = []
  buffer = []
  for char in text:
    if char.isupper() and buffer:
      result.append("".join(buffer))
      buffer = [char]
    else:
      buffer.append(char)
  if buffer:
    result.append("".join(buffer))
  return " ".join(result)


def _is_scalar(value: Any) -> bool:
  return isinstance(value, (str, int, float))


def _write_jobs_file(path: Path, jobs: List[Dict[str, Any]]) -> None:
  """수집한 채용공고를 JSON 파일로 저장한다."""
  try:
    with path.open("w", encoding="utf-8") as fp:
      json.dump(jobs, fp, ensure_ascii=False, indent=2)
  except OSError as error:
    print(f"[ERROR] jobs.json 파일을 저장하는 데 실패했습니다: {error}")


def _copy_to_assets(source: Path, destination: Path) -> None:
  """생성된 JSON 파일을 Flutter assets 폴더로 복사한다."""
  try:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
  except OSError as error:
    print(f"[ERROR] assets 폴더로 파일을 복사하는 데 실패했습니다: {error}")


if __name__ == "__main__":
  # 스크립트가 단독 실행될 때만 main()을 호출한다.
  main()