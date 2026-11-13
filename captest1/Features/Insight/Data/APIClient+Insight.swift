//
//  APIClient+Insight.swift
//  captest1
//

import Foundation

extension APIClient: InsightRepository {
    func caffeineSleepReport(from: String, to: String, timeZone: TimeZone) async throws -> CaffeineSleepReportResponse {
        try await get(
            path: "/api/insight/caffeine-sleep",
            query: ["from": from, "to": to, "tz": timeZone.identifier]
        )
    }
}
