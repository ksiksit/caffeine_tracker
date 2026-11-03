//
//  FakeLearningRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeLearningRepository: LearningRepository, @unchecked Sendable {
    @Locked var runResult: Result<LearningRunResponse, Error> = .success(LearningRunResponse(updatedCount: 0, skipReason: nil, skipMessage: nil))
    @Locked var dashboardResult: Result<LearningDashboardResponse, Error> = .success(.fixture())
    @Locked private(set) var calls: [String] = []

    func run(timeZone: TimeZone) async throws -> LearningRunResponse {
        $calls.mutate { $0.append("run") }
        return try runResult.get()
    }

    func dashboard() async throws -> LearningDashboardResponse {
        $calls.mutate { $0.append("dashboard") }
        return try dashboardResult.get()
    }
}
