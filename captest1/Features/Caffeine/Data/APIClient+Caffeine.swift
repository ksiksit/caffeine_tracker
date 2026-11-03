//
//  APIClient+Caffeine.swift
//  captest1
//

import Foundation

extension APIClient: CaffeineRepository {
    /// 오늘 현황(차트·잔량·마감시각)을 서버가 settings를 읽어 계산해 반환.
    func today(now: Date, timeZone: TimeZone) async throws -> CaffeineTodayResponse {
        try await get(
            path: "/api/caffeine/today",
            query: ["now": ServerDateCoding.isoOffset(now), "tz": timeZone.identifier]
        )
    }

    func create(_ req: CreateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        try await post(path: "/api/caffeine-records", body: req)
    }

    func update(id: Int64, _ req: UpdateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        try await put(path: "/api/caffeine-records/\(id)", body: req)
    }

    func delete(id: Int64) async throws {
        try await delete(path: "/api/caffeine-records/\(id)")
    }
}
