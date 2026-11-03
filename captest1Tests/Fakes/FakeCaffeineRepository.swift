//
//  FakeCaffeineRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeCaffeineRepository: CaffeineRepository, @unchecked Sendable {
    @Locked var todayResult: Result<CaffeineTodayResponse, Error> = .success(.fixture())
    @Locked var createResult: Result<CaffeineRecordDTO, Error> = .success(.fixture())
    @Locked var updateResult: Result<CaffeineRecordDTO, Error> = .success(.fixture())
    @Locked var deleteError: Error? = nil
    /// 호출 순서 기록: "today" / "create" / "update" / "delete"
    @Locked private(set) var calls: [String] = []

    func today(now: Date, timeZone: TimeZone) async throws -> CaffeineTodayResponse {
        $calls.mutate { $0.append("today") }
        return try todayResult.get()
    }

    func create(_ req: CreateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        $calls.mutate { $0.append("create") }
        return try createResult.get()
    }

    func update(id: Int64, _ req: UpdateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        $calls.mutate { $0.append("update") }
        return try updateResult.get()
    }

    func delete(id: Int64) async throws {
        $calls.mutate { $0.append("delete") }
        if let deleteError { throw deleteError }
    }
}
