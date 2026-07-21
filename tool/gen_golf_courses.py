#!/usr/bin/env python3
"""전국 골프장 데이터 → lib/features/golf/data/golf_courses_data.dart 생성.

BadaMobile의 tool/gen_coast.py 와 같은 역할: 공공데이터를 앱이 쓰는 Dart const
리스트로 굽는다. 지금 저장소의 golf_courses_data.dart 는 손으로 채운 시드이며,
아래 절차로 전국 ~510개 전체 목록으로 교체한다.

입력은 CSV 또는 odcloud API JSON 응답 파일을 모두 지원한다(확장자로 판별).

준비:
  - CSV: data.go.kr 로그인 후 "문화체육관광부_전국 골프장 현황"(15118920)에서
    파일데이터를 내려받는다.
  - JSON: odcloud 오픈API 응답을 저장한다. 예(사용자 로컬에서, KEY 본인 것):
      curl "https://api.odcloud.kr/api/15118920/v1/uddi:<GUID>?page=1&perPage=1000&serviceKey=<KEY>&returnType=JSON" -o golf.json
    응답 형식 {"data":[{...}], ...} 또는 dict 배열을 그대로 읽는다.

컬럼/필드명은 자동 인식한다(아래 CANDIDATES). 위경도가 없고 주소만 있으면
좌표를 채운 파일(LX 공간정보/지오코딩)을 준비한다.

사용:
  python3 tool/gen_golf_courses.py golf.csv  > lib/features/golf/data/golf_courses_data.dart
  python3 tool/gen_golf_courses.py golf.json > lib/features/golf/data/golf_courses_data.dart

주의: 좌표(위/경도)가 있는 행만 방출한다. 좌표 없는 행 수는 stderr로 보고한다.
"""
import csv
import hashlib
import json
import re
import sys
import unicodedata

# 컬럼 자동 인식 후보(대소문자·공백 무시, 부분일치).
CANDIDATES = {
    "name": ["사업장명", "골프장명", "업소명", "명칭", "name"],
    "address": ["도로명주소", "소재지도로명주소", "지번주소", "소재지지번주소",
                "주소", "address"],
    "lat": ["위도", "lat", "latitude", "y", "ycrd"],
    "lon": ["경도", "lon", "lng", "longitude", "x", "xcrd"],
    "holes": ["홀수", "홀", "hole", "holes"],
    "type": ["구분", "업종", "유형", "회원제구분", "type"],
}

REGION_PREFIX = [
    ("수도권", ["서울", "인천", "경기"]),
    ("강원", ["강원"]),
    ("충청", ["대전", "세종", "충북", "충남", "충청"]),
    ("영남", ["부산", "대구", "울산", "경북", "경남", "경상"]),
    ("호남", ["광주", "전북", "전남", "전라"]),
    ("제주", ["제주"]),
]


def norm(s):
    return unicodedata.normalize("NFKC", (s or "")).strip()


def pick_columns(header):
    idx = {}
    low = [norm(h).replace(" ", "") for h in header]
    for field, cands in CANDIDATES.items():
        for c in cands:
            for i, h in enumerate(low):
                if c.replace(" ", "") in h:
                    idx[field] = i
                    break
            if field in idx:
                break
    return idx


def region_of(addr):
    a = norm(addr)
    for region, prefixes in REGION_PREFIX:
        if any(a.startswith(p) or p in a[:6] for p in prefixes):
            return region
    return "기타"


def slugify(name, seq):
    # 한글 골프장명은 ascii로 거의 남지 않아(대부분 'cc'/'gc') 겹친다. 의미 있는
    # ascii가 3자 이상이면 그걸 쓰고, 아니면 이름 해시로 안정적 고유 id를 만든다.
    base = re.sub(r"[^a-z0-9]+", "_", norm(name).lower()).strip("_")
    stripped = base.replace("_", "")
    if len(stripped) >= 3 and stripped not in ("cc", "gc", "golf"):
        return base
    h = hashlib.md5(norm(name).encode("utf-8")).hexdigest()[:8]
    return f"gc_{h}"


def to_float(s):
    try:
        return float(str(s).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def dart_str(s):
    """Dart 작은따옴표 문자열에 안전하도록 이스케이프."""
    return norm(s).replace("\\", "").replace("'", "’").replace("$", "")


def load_records(path):
    """CSV 또는 JSON에서 dict(필드명→값) 목록을 만든다."""
    if path.lower().endswith(".json"):
        with open(path, encoding="utf-8-sig") as f:
            data = json.load(f)
        if isinstance(data, dict):
            data = data.get("data") or data.get("records") or []
        return [dict(r) for r in data]
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        return [dict(zip(header, row)) for row in reader]


def build_record(get, seq, seen):
    name = norm(get("name"))
    lat = to_float(get("lat"))
    lon = to_float(get("lon"))
    if not name or lat is None or lon is None:
        return None
    gid = slugify(name, seq)
    while gid in seen:
        gid += "_x"
    seen.add(gid)
    addr = norm(get("address"))
    holes = re.sub(r"[^0-9]", "", get("holes") or "") or "18"
    return {
        "id": gid, "name": name, "region": region_of(addr),
        "lat": lat, "lon": lon, "address": addr,
        "holes": int(holes), "type": norm(get("type")),
    }


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    records = load_records(sys.argv[1])
    if not records:
        sys.exit("입력에 레코드가 없습니다.")
    keys = list(records[0].keys())
    idx = pick_columns(keys)  # {field: index in keys}
    if "name" not in idx or "lat" not in idx or "lon" not in idx:
        sys.exit(f"필수 필드(name/lat/lon)를 못 찾음. 인식된 필드: {idx}\n전체 필드: {keys}")
    field_key = {f: keys[i] for f, i in idx.items()}

    rows, skipped, seen = [], 0, set()
    for seq, rec in enumerate(records):
        def get(field):
            k = field_key.get(field)
            return "" if k is None else str(rec.get(k, "") or "")
        r = build_record(get, seq, seen)
        if r is None:
            skipped += 1
        else:
            rows.append(r)

    out = sys.stdout
    out.write("import 'models/golf_course.dart';\n\n")
    out.write("/// 전국 골프장(문화체육관광부 전국 골프장 현황 기반, 자동 생성).\n")
    out.write("/// 재생성: python3 tool/gen_golf_courses.py <csv|json>\n")
    out.write("const List<GolfCourse> golfCourses = [\n")
    for r in rows:
        out.write("  GolfCourse(\n")
        out.write(f"    id: '{r['id']}',\n")
        out.write(f"    name: '{dart_str(r['name'])}',\n")
        out.write(f"    region: '{r['region']}',\n")
        out.write(f"    latitude: {r['lat']:.5f},\n")
        out.write(f"    longitude: {r['lon']:.5f},\n")
        out.write(f"    address: '{dart_str(r['address'])}',\n")
        out.write(f"    holes: {r['holes']},\n")
        out.write(f"    type: '{dart_str(r['type'])}',\n")
        out.write("  ),\n")
    out.write("];\n")
    print(f"생성 {len(rows)}개, 좌표 없어 건너뜀 {skipped}개", file=sys.stderr)


if __name__ == "__main__":
    main()
