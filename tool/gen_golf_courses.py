#!/usr/bin/env python3
"""전국 골프장 CSV → lib/features/golf/data/golf_courses_data.dart 생성.

BadaMobile의 tool/gen_coast.py 와 같은 역할: 공공데이터를 앱이 쓰는 Dart const
리스트로 굽는다. 지금 저장소의 golf_courses_data.dart 는 손으로 채운 시드이며,
아래 절차로 전국 ~510개 전체 목록으로 교체한다.

준비:
  1) data.go.kr 로그인 후 "문화체육관광부_전국 골프장 현황"(15118920)에서
     CSV 파일을 내려받는다(프록시로는 직접 다운로드가 막혀 있어 수동 저장).
  2) CSV에 위경도가 없으면(주소만 있으면) LX 공간정보 또는 지오코딩으로
     좌표를 채운 CSV를 준비한다. 컬럼명은 자동 인식한다(아래 CANDIDATES).

사용:
  python3 tool/gen_golf_courses.py golf.csv > \
      lib/features/golf/data/golf_courses_data.dart

주의: 좌표(위/경도)가 있는 행만 방출한다. 좌표 없는 행 수는 stderr로 보고한다.
"""
import csv
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
    base = re.sub(r"[^a-z0-9]+", "_", norm(name).lower()).strip("_")
    return base or f"course_{seq}"


def to_float(s):
    try:
        return float(str(s).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        idx = pick_columns(header)
        if "name" not in idx or "lat" not in idx or "lon" not in idx:
            sys.exit(f"필수 컬럼(name/lat/lon)을 못 찾음. 인식된 컬럼: {idx}")
        rows, skipped, seen = [], 0, set()
        for seq, row in enumerate(reader):
            def cell(field):
                i = idx.get(field)
                return row[i] if i is not None and i < len(row) else ""
            name = norm(cell("name"))
            lat = to_float(cell("lat"))
            lon = to_float(cell("lon"))
            if not name or lat is None or lon is None:
                skipped += 1
                continue
            gid = slugify(name, seq)
            while gid in seen:
                gid += "_x"
            seen.add(gid)
            addr = norm(cell("address"))
            holes = re.sub(r"[^0-9]", "", cell("holes")) or "18"
            gtype = norm(cell("type")) or ""
            rows.append({
                "id": gid, "name": name, "region": region_of(addr),
                "lat": lat, "lon": lon, "address": addr,
                "holes": int(holes), "type": gtype,
            })

    out = sys.stdout
    out.write("import 'models/golf_course.dart';\n\n")
    out.write("/// 전국 골프장(문화체육관광부 전국 골프장 현황 기반, 자동 생성).\n")
    out.write("/// 재생성: python3 tool/gen_golf_courses.py <csv>\n")
    out.write("const List<GolfCourse> golfCourses = [\n")
    for r in rows:
        out.write("  GolfCourse(\n")
        out.write(f"    id: '{r['id']}',\n")
        out.write(f"    name: '{r['name']}',\n")
        out.write(f"    region: '{r['region']}',\n")
        out.write(f"    latitude: {r['lat']:.5f},\n")
        out.write(f"    longitude: {r['lon']:.5f},\n")
        out.write(f"    address: '{r['address']}',\n")
        out.write(f"    holes: {r['holes']},\n")
        out.write(f"    type: '{r['type']}',\n")
        out.write("  ),\n")
    out.write("];\n")
    print(f"생성 {len(rows)}개, 좌표 없어 건너뜀 {skipped}개", file=sys.stderr)


if __name__ == "__main__":
    main()
