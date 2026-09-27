"""
카페 구역 데이터 검증. 실패하면 이유를 출력하고 종료 코드 1.

  python3 tools/cafe-zones/check_zones.py

1. 골든: 양재2동 원본(fixtures/yangjae2_all_cafes.csv)을 build_zones.cluster로 묶은 결과가
   탐색 분석 결과(fixtures/yangjae2_zones.json, 지오펜스 시험 앱이 쓴 값)와 맞는지.
   카페 107곳 · 25구역 · 카페 수 순서 일치 · 상위 3구역 중심 1m 이내.
   (카페 수가 같은 하위 구역은 동률 처리에 따라 중심이 달라질 수 있어 비교하지 않는다.)
2. 번들 파일(captest1/Resources/CafeZones.json): 스키마 · 동 3,400개 이상 · 동마다 17구역 이하 · 카페 수 내림차순 ·
   좌표 국내 범위 · 4MB 이하 · 양재2동 = 골든 묶기 결과의 상위 17개.
"""
import csv
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_zones as bz  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(HERE, "fixtures")
YANGJAE2_CODE = "11650652"
MAX_BYTES = 4 * 1024 * 1024
MIN_DONGS = 3_400

failures = []


def check(ok, message):
    if not ok:
        failures.append(message)


def distance_m(a, b):
    x1, y1 = bz.to_xy_m(a[0], a[1], a[0])
    x2, y2 = bz.to_xy_m(b[0], b[1], a[0])
    return math.hypot(x1 - x2, y1 - y2)


def golden():
    with open(os.path.join(FIXTURES, "yangjae2_all_cafes.csv"), encoding="utf-8-sig") as f:
        points = [(float(r["위도"]), float(r["경도"])) for r in csv.DictReader(f)]
    points = bz.dedupe(points)
    zones = bz.cluster(points)
    with open(os.path.join(FIXTURES, "yangjae2_zones.json"), encoding="utf-8") as f:
        gold = json.load(f)["zones"]
    check(len(points) == 107, f"양재2동 중복 제거 후 카페 수 {len(points)} ≠ 107")
    check(len(zones) == 25, f"양재2동 구역 수 {len(zones)} ≠ 25")
    check([z[2] for z in zones] == [g["count"] for g in gold],
          f"양재2동 카페 수 순서 불일치: {[z[2] for z in zones]}")
    for i in range(3):
        d = distance_m(zones[i][:2], (gold[i]["lat"], gold[i]["lng"]))
        check(d <= 1.0, f"양재2동 {i + 1}번째 구역 중심이 골든과 {d:.1f}m 떨어짐")
    return zones


def bundle(golden_zones):
    path = bz.DEFAULT_OUT
    if not os.path.exists(path):
        check(False, f"번들 파일 없음: {path}")
        return
    size = os.path.getsize(path)
    check(size <= MAX_BYTES, f"번들 파일 {size:,} B > {MAX_BYTES:,} B")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    check(set(data) == {"source", "radiusM", "maxZonesPerDong", "dongs"}, f"최상위 키 불일치: {sorted(data)}")
    check(data.get("radiusM") == 150 and data.get("maxZonesPerDong") == 17, "radiusM·maxZonesPerDong 값 불일치")
    dongs = data.get("dongs", [])
    check(len(dongs) >= MIN_DONGS, f"동 {len(dongs)}개 < {MIN_DONGS}")
    codes = set()
    for d in dongs:
        label = f"{d.get('code')} {d.get('name')}"
        check(set(d) == {"code", "sido", "sigungu", "name", "zones"}, f"{label}: 키 불일치 {sorted(d)}")
        check(d["code"] not in codes, f"{label}: 코드 중복")
        codes.add(d["code"])
        zones = d["zones"]
        check(1 <= len(zones) <= 17, f"{label}: 구역 {len(zones)}개")
        counts = [z[2] for z in zones]
        check(counts == sorted(counts, reverse=True), f"{label}: 카페 수 내림차순 아님")
        for lat, lng, count in zones:
            if not (bz.KOREA_LAT[0] <= lat <= bz.KOREA_LAT[1] and bz.KOREA_LNG[0] <= lng <= bz.KOREA_LNG[1]):
                check(False, f"{label}: 국내 범위 밖 좌표 {lat},{lng}")
            check(isinstance(count, int) and count >= 1, f"{label}: 카페 수 {count}")
    yangjae2 = next((d for d in dongs if d["code"] == YANGJAE2_CODE), None)
    check(yangjae2 is not None and yangjae2["name"] == "양재2동", f"양재2동({YANGJAE2_CODE}) 없음")
    if yangjae2:
        expected = [list(z) for z in golden_zones[:17]]
        check(yangjae2["zones"] == expected, "번들의 양재2동 구역이 골든 묶기 결과 상위 17개와 다름")
    print(f"번들: 동 {len(dongs):,}개, 구역 {sum(len(d['zones']) for d in dongs):,}개, {size:,} B")


def main():
    zones = golden()
    bundle(zones)
    if failures:
        print(f"실패 {len(failures)}건", file=sys.stderr)
        for m in failures[:30]:
            print(f"  - {m}", file=sys.stderr)
        sys.exit(1)
    print("통과")


if __name__ == "__main__":
    main()
