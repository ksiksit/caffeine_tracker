//
//  CaffeineRepository.swift
//  captest1
//
//  카페인 도메인 포트(서버 domain/caffeine). 잔류량·차트·마감시각 계산은 서버가 한다.
//

import Foundation

nonisolated protocol CaffeineRepository: Sendable {
    func today(now: Date, timeZone: TimeZone) async throws -> CaffeineTodayResponse
    func create(_ req: CreateCaffeineRecordRequest) async throws -> CaffeineRecordDTO
    func update(id: Int64, _ req: UpdateCaffeineRecordRequest) async throws -> CaffeineRecordDTO
    func delete(id: Int64) async throws
}

extension CaffeineRepository {
    /// 현재 시각·현재 타임존 기준 오늘 현황.
    func today() async throws -> CaffeineTodayResponse {
        try await today(now: Date(), timeZone: .current)
    }
}
