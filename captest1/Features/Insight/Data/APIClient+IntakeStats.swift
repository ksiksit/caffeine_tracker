//
//  APIClient+IntakeStats.swift
//  captest1
//

import Foundation

extension APIClient: IntakeStatsRepository {
    func intakeStats(from: String, to: String, timeZone: TimeZone) async throws -> IntakeStatsResponse {
        try await get(
            path: "/api/insight/intake-stats",
            query: ["from": from, "to": to, "tz": timeZone.identifier]
        )
    }
}
