//
//  APIClient+Learning.swift
//  captest1
//

import Foundation

extension APIClient: LearningRepository {
    func run(timeZone: TimeZone) async throws -> LearningRunResponse {
        try await post(path: "/api/learning/run", query: ["tz": timeZone.identifier])
    }

    func dashboard() async throws -> LearningDashboardResponse {
        try await get(path: "/api/learning/dashboard")
    }
}
