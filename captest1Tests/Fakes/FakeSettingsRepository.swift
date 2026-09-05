//
//  FakeSettingsRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeSettingsRepository: SettingsRepository, @unchecked Sendable {
    @Locked var getResult: Result<SettingsResponse, Error> = .success(.fixture())
    /// nil이면 요청값을 그대로 돌려준다(서버 에코).
    @Locked var updateOverride: Result<SettingsResponse, Error>? = nil
    @Locked private(set) var updateRequests: [UpdateSettingsRequest] = []

    func settings() async throws -> SettingsResponse {
        try getResult.get()
    }

    func updateSettings(_ req: UpdateSettingsRequest) async throws -> SettingsResponse {
        $updateRequests.mutate { $0.append(req) }
        if let updateOverride { return try updateOverride.get() }
        let base = try getResult.get()
        return SettingsResponse.fixture(
            halfLife: req.halfLife, condition: req.condition,
            bedtimeHour: req.bedtimeHour, bedtimeMinute: req.bedtimeMinute,
            referenceDoseMg: req.referenceDoseMg, isLearningEnabled: req.isLearningEnabled,
            learnedMean: base.learnedMean, learnedVariance: base.learnedVariance, lastLearnedDate: base.lastLearnedDate
        )
    }
}
