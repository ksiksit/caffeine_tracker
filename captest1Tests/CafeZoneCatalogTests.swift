//
//  CafeZoneCatalogTests.swift
//  captest1Tests
//
//  앱 번들의 실제 CafeZones.json(tools/cafe-zones/build_zones.py 생성)을 읽는다.
//

import Foundation
import Testing
@testable import captest1

struct CafeZoneCatalogTests {
    /// 테스트는 앱에 올라타 실행되므로 main이 앱 번들이다.
    private let catalog = BundledCafeZoneCatalog(bundle: .main)

    @Test func loadsBundledNationwideData() async throws {
        let dongs = try await catalog.dongs()
        #expect(dongs.count >= 3_400)
        #expect(dongs.allSatisfy { !$0.zones.isEmpty && $0.zones.count <= CafeNearbyStore.zoneLimit })
    }

    @Test func yangjae2_matchesGoldenTopZone() async throws {
        let dongs = try await catalog.dongs()
        let yangjae2 = try #require(dongs.first { $0.code == "11650652" })
        #expect(yangjae2.name == "양재2동")
        #expect(yangjae2.sigungu == "서초구")
        #expect(yangjae2.zones.count == 17)
        #expect(yangjae2.zones.first == CafeZone(latitude: 37.476024, longitude: 127.04417, cafeCount: 23))
        #expect(yangjae2.zones.map(\.cafeCount) == yangjae2.zones.map(\.cafeCount).sorted(by: >))
    }

    @Test func missingResource_throws() async {
        // 테스트 번들 자체에는 CafeZones.json이 없다.
        let empty = BundledCafeZoneCatalog(bundle: Bundle(for: TestBundleAnchor.self))
        await #expect(throws: BundledCafeZoneCatalog.LoadError.self) {
            _ = try await empty.dongs()
        }
    }
}

/// 테스트 번들을 찾기 위한 표식 클래스.
private final class TestBundleAnchor {}
