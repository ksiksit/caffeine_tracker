//
//  FakeCafeZoneCatalog.swift
//  captest1Tests
//

import Foundation
@testable import captest1

nonisolated struct FakeCafeZoneCatalog: CafeZoneCatalog {
    var radius: Double = 150
    var result: Result<[CafeDong], FakeError>

    init(_ dongs: [CafeDong]) {
        result = .success(dongs)
    }

    init(failure: FakeError) {
        result = .failure(failure)
    }

    func dongs() async throws -> [CafeDong] {
        try result.get()
    }
}

extension CafeDong {
    /// 카페 수 목록으로 구역을 만든다. 좌표는 동 코드·순번으로 겹치지 않게.
    static func fixture(code: String, name: String, sigungu: String = "서초구", counts: [Int]) -> CafeDong {
        let base = Double(Int(code.suffix(3)) ?? 0) / 1000
        return CafeDong(
            code: code, sido: "서울특별시", sigungu: sigungu, name: name,
            zones: counts.enumerated().map { i, count in
                CafeZone(latitude: 37 + base + Double(i) / 10_000, longitude: 127 + base, cafeCount: count)
            })
    }
}
