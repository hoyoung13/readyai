"""Utility script to fetch ongoing public institution recruitments.

This script uses the 기획재정부_공공기관 채용정보 조회서비스 OpenAPI to collect
all ongoing (``ongoingYn == 'Y'``) recruitments.  For every listing it also
fetches the detailed view information and stores both payloads side-by-side in
``results.json``.

Usage
-----
Set the environment variable ``MOEF_RECRUITMENT_SERVICE_KEY`` with your
**Decoding** service key and run the script with ``python fetch_moef_ongoing_recruitments.py``.
"""

from __future__ import annotations

import json
import os
import sys
import time
from typing import Any, Dict, Iterable, List, Optional

try:
    # requests는 HTTP 통신을 간편하게 해 주는 외부 라이브러리다.
    import requests
except ImportError as error:  # pragma: no cover - 실행 환경에 따라 설치되지 않을 수 있다.
    requests = None  # type: ignore[assignment]
    IMPORT_ERROR = error
else:
    IMPORT_ERROR = None

# OpenAPI 엔드포인트 정의
LIST_ENDPOINT = "https://apis.data.go.kr/1051000/recruitment/list"
DETAIL_ENDPOINT = "https://apis.data.go.kr/1051000/recruitment/view"

# API 호출에 공통으로 사용할 기본 파라미터
NUM_ROWS = 20
COMMON_PARAMS = {
    "numOfRows": str(NUM_ROWS),
    "type": "json",
}

# 서비스 키를 읽어올 환경 변수 이름
SERVICE_KEY_ENV = "MOEF_RECRUITMENT_SERVICE_KEY"

# API 요청 사이에 둘 지연(초)
REQUEST_DELAY = 0.3


def ensure_requests_installed() -> None:
    """requests 모듈이 설치되어 있는지 확인한다."""

    if requests is None:  # pragma: no cover - 단순 종료 경로
        raise SystemExit(
            "The 'requests' package is required to run this script."
            f" ({IMPORT_ERROR})"
        )


def get_service_key() -> str:
    """환경 변수에서 서비스 키를 읽고 검증한다."""

    service_key = os.getenv(SERVICE_KEY_ENV)
    if not service_key:
        raise SystemExit(
            "환경 변수 'MOEF_RECRUITMENT_SERVICE_KEY'에 Decoding 버전 인증키를 설정해 주세요."
        )
    return service_key


def extract_items(response_json: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    """목록 응답에서 채용 공고 목록을 추출한다."""

    result = response_json.get("result")
    if isinstance(result, list):
        for entry in result:
            if isinstance(entry, dict):
                item = entry.get("item")
                if isinstance(item, dict):
                    yield entry  # 목록 응답 원본 구조를 그대로 유지한다.
                elif entry:  # item 키가 없다면 entry 자체를 반환한다.
                    yield entry
    elif isinstance(result, dict):
        # result가 dict인 경우 item 키를 직접 확인한다.
        item = result.get("item")
        if isinstance(item, list):
            for entry in item:
                if isinstance(entry, dict):
                    yield entry
        elif isinstance(item, dict):
            yield item


def fetch_json(url: str, params: Dict[str, Any]) -> Dict[str, Any]:
    """주어진 URL로 GET 요청을 보내고 JSON 응답을 반환한다."""

    response = requests.get(url, params=params, timeout=30)
    response.raise_for_status()
    data = response.json()
    # 서버 부하를 줄이기 위해 매 요청 후 잠시 대기한다.
    time.sleep(REQUEST_DELAY)
    return data


def fetch_all_listings(service_key: str) -> List[Dict[str, Any]]:
    """모든 페이지를 순회하며 진행 중인 채용 공고 목록을 수집한다."""

    ongoing_listings: List[Dict[str, Any]] = []
    page_no = 1
    total_count: Optional[int] = None

    while True:
        params = {
            "serviceKey": service_key,
            "pageNo": str(page_no),
            **COMMON_PARAMS,
        }

        try:
            list_response = fetch_json(LIST_ENDPOINT, params)
        except Exception as error:  # pragma: no cover - 네트워크 오류 등 예외 처리
            print(f"⚠️ 목록 조회 실패 (page {page_no}): {error}")
            break

        if total_count is None:
            # totalCount는 문자열일 수 있으므로 안전하게 정수로 변환한다.
            try:
                total_count = int(list_response.get("totalCount", 0))
            except (TypeError, ValueError):
                total_count = 0

        page_items = list(extract_items(list_response))
        if not page_items:
            # 더 이상 항목이 없으면 반복을 종료한다.
            break

        for entry in page_items:
            # entry에 item이 포함되어 있으면 해당 dict를 사용한다.
            item = entry.get("item") if isinstance(entry, dict) else None
            item_data = item if isinstance(item, dict) else entry

            ongoing_flag = str(item_data.get("ongoingYn", "")).upper()
            if ongoing_flag == "Y":
                ongoing_listings.append({"listItem": entry})

        # 수집 대상이 total_count 이상이면 종료한다.
        if total_count is not None and page_no * NUM_ROWS >= total_count:
            break

        page_no += 1

    return ongoing_listings


def fetch_detail(service_key: str, recrut_pblnt_sn: Any) -> Optional[Dict[str, Any]]:
    """단일 채용 공고의 상세 정보를 조회한다."""

    params = {
        "serviceKey": service_key,
        "recrutPblntSn": str(recrut_pblnt_sn),
        "type": "json",
    }

    try:
        detail_response = fetch_json(DETAIL_ENDPOINT, params)
    except Exception as error:
        print(f"⚠️ 상세 조회 실패 (recrutPblntSn={recrut_pblnt_sn}): {error}")
        return None

    return detail_response


def main() -> None:
    """스크립트 진입점."""

    ensure_requests_installed()
    service_key = get_service_key()

    # 모든 진행 중인 채용 공고 목록을 조회한다.
    ongoing_listings = fetch_all_listings(service_key)

    results: List[Dict[str, Any]] = []

    for listing in ongoing_listings:
        list_item = listing.get("listItem", {})
        item_data = list_item.get("item") if isinstance(list_item, dict) else None
        if not isinstance(item_data, dict):
            item_data = list_item

        recrut_pblnt_sn = item_data.get("recrutPblntSn")
        if recrut_pblnt_sn is None:
            print("⚠️ recrutPblntSn 값이 없어 상세 조회를 건너뜁니다.")
            results.append({"listItem": list_item, "detailItem": None})
            continue

        try:
            detail_data = fetch_detail(service_key, recrut_pblnt_sn)
        except Exception as error:  # pragma: no cover - 예기치 못한 예외 방지
            print(f"⚠️ 상세 조회 처리 중 오류 발생: {error}")
            detail_data = None

        results.append({"listItem": list_item, "detailItem": detail_data})

    # JSON 결과를 파일로 저장한다.
    output_path = os.path.join(os.path.dirname(__file__), "results.json")
    with open(output_path, "w", encoding="utf-8") as output_file:
        json.dump(results, output_file, ensure_ascii=False, indent=2)

    print(f"✅ 총 {len(results)}개의 진행 중인 채용공고 저장 완료 (results.json)")


if __name__ == "__main__":
    try:
        main()
    except SystemExit as error:
        # SystemExit은 사용자에게 메시지를 보여 준 후 조용히 종료한다.
        if error.code:
            print(error)
        sys.exit(error.code if isinstance(error.code, int) else 1)