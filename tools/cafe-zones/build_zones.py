"""
전국 카페 구역 데이터 생성 — 앱 번들 `captest1/Resources/CafeZones.json`.

사용법 (표준 라이브러리만 사용):
  python3 tools/cafe-zones/build_zones.py --raw <상가(상권)정보 zip 또는 CSV 폴더>

규칙:
  1. 업종 소분류코드 I21201(카페)만. 스터디카페(R10202) 제외.
  2. 좌표가 국내 범위 밖이면 버림. 같은 행정동 안에서 (위도, 경도)가 같은 행은 하나로 친다
     (같은 건물·같은 좌표에 상호만 다른 중복 — 양재2동 126곳 → 107곳).
  3. 행정동마다 반경 상한 묶기: 남은 카페 중 반경 150m 안 이웃이 가장 많은 카페를 중심으로 원을 떼어내기를 반복.
     동률이면 (위도, 경도)가 작은 쪽 — 결정적이어야 재생성해도 같은 파일이 나온다.
  4. 동마다 카페 수 내림차순 상위 17구역만 (iOS 앱당 감시 구역 20개 중 3자리는 예비).

출력 형식 (minified):
  {"source", "radiusM", "maxZonesPerDong",
   "dongs": [{"code", "sido", "sigungu", "name", "zones": [[lat, lng, count], ...]}]}
"""
import argparse
import csv
import glob
import io
import json
import math
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_RAW = os.path.normpath(os.path.join(HERE, "..", "..", "..", "data-check", "raw"))
DEFAULT_OUT = os.path.normpath(os.path.join(HERE, "..", "..", "captest1", "Resources", "CafeZones.json"))

SOURCE = "소상공인시장진흥공단 상가(상권)정보 2026-06-30"
CAFE_CODE = "I21201"
RADIUS_M = 150.0
MAX_ZONES_PER_DONG = 17
KOREA_LAT = (33.0, 38.7)
KOREA_LNG = (124.5, 132.0)


# MARK: - 묶기 (check_zones.py도 이 함수를 쓴다)

def to_xy_m(lat, lng, lat0):
    """작은 영역용 평면 근사(미터). 동 단위 거리 계산엔 충분히 정확."""
    return (lng * 111_320.0 * math.cos(math.radians(lat0)), lat * 110_540.0)


def dedupe(points):
    """(위도, 경도)가 같은 점은 하나로. 순서는 처음 나온 순."""
    seen = set()
    out = []
    for p in points:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def cluster(points, radius=RADIUS_M):
    """반경 상한 묶기. points: [(lat, lng)] (중복 제거 후). 반환: [(lat, lng, count)] 카페 수 내림차순 전체."""
    n = len(points)
    if n == 0:
        return []
    lat0 = sum(p[0] for p in points) / n
    xy = [to_xy_m(lat, lng, lat0) for lat, lng in points]
    # 격자 해시로 이웃 후보만 비교 — 카페 500곳 넘는 동도 빠르게
    cells = {}
    for i, (x, y) in enumerate(xy):
        cells.setdefault((int(x // radius), int(y // radius)), []).append(i)
    neighbors = []
    for i, (x, y) in enumerate(xy):
        cx, cy = int(x // radius), int(y // radius)
        near = set()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for j in cells.get((cx + dx, cy + dy), ()):
                    if math.hypot(x - xy[j][0], y - xy[j][1]) <= radius:
                        near.add(j)
        neighbors.append(near)

    remaining = set(range(n))
    zones = []
    while remaining:
        best = max(remaining, key=lambda i: (len(neighbors[i] & remaining), -points[i][0], -points[i][1]))
        members = neighbors[best] & remaining
        zones.append((round(points[best][0], 6), round(points[best][1], 6), len(members)))
        remaining -= members
    zones.sort(key=lambda z: -z[2])  # 안정 정렬 — 같은 수면 뽑힌 순서 유지
    return zones


# MARK: - 원본 읽기

def detect_encoding(head: bytes) -> str:
    try:
        head.decode("utf-8")
        return "utf-8-sig"
    except UnicodeDecodeError as e:
        # 잘린 멀티바이트 끝부분 때문일 수 있으니 앞부분만 다시 확인
        try:
            head[: e.start].decode("utf-8")
            if e.start > len(head) - 4:
                return "utf-8-sig"
        except UnicodeDecodeError:
            pass
        return "cp949"


def iter_sources(raw):
    """(이름, 바이너리 파일 여는 함수) — zip 안 CSV와 폴더의 CSV."""
    paths = [raw] if os.path.isfile(raw) else sorted(glob.glob(os.path.join(raw, "**", "*"), recursive=True))
    for path in paths:
        low = path.lower()
        if low.endswith(".zip"):
            zf = zipfile.ZipFile(path)
            for info in zf.infolist():
                if info.filename.lower().endswith(".csv"):
                    # zip에 UTF-8 플래그가 없으면 파일명이 cp949라 cp437로 잘못 풀린 것을 되돌린다
                    name = info.filename if info.flag_bits & 0x800 else info.filename.encode("cp437").decode("cp949", "replace")
                    yield name, (lambda i=info, z=zf: z.open(i))
        elif low.endswith(".csv"):
            yield path, (lambda p=path: open(p, "rb"))


def read_cafes(raw):
    """행정동코드 → {"sido", "sigungu", "name", "points": [(lat, lng)]}"""
    dongs = {}
    total = 0
    for name, open_fn in iter_sources(raw):
        with open_fn() as f:
            enc = detect_encoding(f.read(200_000))
        with open_fn() as f:
            reader = csv.DictReader(io.TextIOWrapper(f, encoding=enc, newline=""))
            for row in reader:
                total += 1
                if (row.get("상권업종소분류코드") or "").strip() != CAFE_CODE:
                    continue
                try:
                    lat = float(row["위도"])
                    lng = float(row["경도"])
                except (TypeError, ValueError, KeyError):
                    continue
                if not (KOREA_LAT[0] <= lat <= KOREA_LAT[1] and KOREA_LNG[0] <= lng <= KOREA_LNG[1]):
                    continue
                code = (row.get("행정동코드") or "").strip()
                if not code:
                    continue
                dong = dongs.setdefault(code, {
                    "sido": row["시도명"].strip(), "sigungu": row["시군구명"].strip(),
                    "name": row["행정동명"].strip(), "points": [],
                })
                dong["points"].append((lat, lng))
        print(f"  읽음: {name} (인코딩 {enc})", file=sys.stderr)
    if total == 0:
        sys.exit(f"원본 CSV를 찾지 못했어요: {raw}")
    print(f"  전체 {total:,}행, 카페가 있는 행정동 {len(dongs):,}개", file=sys.stderr)
    return dongs


def build(raw):
    dongs = read_cafes(raw)
    out = []
    for code in sorted(dongs):
        d = dongs[code]
        zones = cluster(dedupe(d["points"]))[:MAX_ZONES_PER_DONG]
        out.append({"code": code, "sido": d["sido"], "sigungu": d["sigungu"], "name": d["name"],
                    "zones": [[lat, lng, count] for lat, lng, count in zones]})
    return {"source": SOURCE, "radiusM": int(RADIUS_M), "maxZonesPerDong": MAX_ZONES_PER_DONG, "dongs": out}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--raw", default=DEFAULT_RAW, help="상가(상권)정보 zip 파일 또는 CSV·zip이 든 폴더")
    parser.add_argument("--out", default=DEFAULT_OUT)
    args = parser.parse_args()
    data = build(args.raw)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    zones = sum(len(d["zones"]) for d in data["dongs"])
    print(f"완료: {args.out} — 동 {len(data['dongs']):,}개, 구역 {zones:,}개, {os.path.getsize(args.out):,} B", file=sys.stderr)


if __name__ == "__main__":
    main()
