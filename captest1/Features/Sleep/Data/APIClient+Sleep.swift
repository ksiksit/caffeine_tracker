//
//  APIClient+Sleep.swift
//  captest1
//

import Foundation

extension APIClient: SleepRepository {
    func uploadSamples(_ req: UploadSleepSamplesRequest) async throws -> UploadSleepSamplesResponse {
        try await post(path: "/api/sleep/samples", body: req)
    }

    func summary(date: String, timeZone: TimeZone) async throws -> SleepSummaryResponse {
        try await get(path: "/api/sleep/summary", query: ["date": date, "tz": timeZone.identifier])
    }
}
