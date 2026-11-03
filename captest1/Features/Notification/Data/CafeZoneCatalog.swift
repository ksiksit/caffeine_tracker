//
//  CafeZoneCatalog.swift
//  captest1
//
//  전국 카페 구역(번들 CafeZones.json — tools/cafe-zones/build_zones.py로 생성). 행정동마다 반경 150m 구역이 카페 수 순으로 최대 17개.
//  서버에 없는 데이터다: 카페 좌표·사용자 위치는 서버로 보내지 않는다(서버 CLAUDE.md 도메인 계약).
//

import Foundation

/// 카페 구역 하나(반경은 파일 전체 공통).
nonisolated struct CafeZone: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let cafeCount: Int
}

/// 행정동 하나와 그 동의 카페 구역(카페 수 내림차순).
nonisolated struct CafeDong: Identifiable, Equatable, Sendable {
    /// 행정동코드(예: 양재2동 11650652).
    let code: String
    let sido: String
    let sigungu: String
    let name: String
    let zones: [CafeZone]

    var id: String { code }
    /// 목록 표시용 "서초구 양재2동".
    var shortLabel: String { "\(sigungu) \(name)" }
    /// 검색 대상 "서울특별시 서초구 양재2동".
    var fullLabel: String { "\(sido) \(sigungu) \(name)" }
}

/// 전국 카페 구역 포트. 한 번 읽으면 스토어가 들고 있는다.
nonisolated protocol CafeZoneCatalog: Sendable {
    /// 구역 반경(m).
    var radius: Double { get }
    func dongs() async throws -> [CafeDong]
}

/// 앱 번들의 CafeZones.json을 읽는 어댑터.
nonisolated struct BundledCafeZoneCatalog: CafeZoneCatalog {
    static let resourceName = "CafeZones"
    let radius: Double = 150
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    enum LoadError: Error { case missingResource }

    /// 1MB 넘는 JSON이라 메인 스레드 밖에서 읽는다.
    @concurrent
    func dongs() async throws -> [CafeDong] {
        guard let url = bundle.url(forResource: Self.resourceName, withExtension: "json") else {
            throw LoadError.missingResource
        }
        let file = try JSONDecoder().decode(CafeZonesFile.self, from: Data(contentsOf: url))
        return file.dongs.map { d in
            CafeDong(code: d.code, sido: d.sido, sigungu: d.sigungu, name: d.name,
                     zones: d.zones.map { CafeZone(latitude: $0.latitude, longitude: $0.longitude, cafeCount: $0.count) })
        }
    }
}

/// 파일 형식: `{"radiusM","maxZonesPerDong","dongs":[{"code","sido","sigungu","name","zones":[[lat,lng,count]]}]}`
private nonisolated struct CafeZonesFile: Decodable {
    struct Dong: Decodable {
        let code: String
        let sido: String
        let sigungu: String
        let name: String
        let zones: [Zone]
    }

    /// 크기를 줄이려 배열 [위도, 경도, 카페 수]로 저장돼 있다.
    struct Zone: Decodable {
        let latitude: Double
        let longitude: Double
        let count: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            latitude = try c.decode(Double.self)
            longitude = try c.decode(Double.self)
            count = try c.decode(Int.self)
        }
    }

    let dongs: [Dong]
}
