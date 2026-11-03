//
//  FakeSleepRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeSleepSampleSource: SleepSampleSource, @unchecked Sendable {
    @Locked var samples: [RawSleepSample] = []
    @Locked var error: Error? = nil
    @Locked private(set) var fetchCount = 0

    func fetchRawSamples(for date: Date) async throws -> [RawSleepSample] {
        $fetchCount.mutate { $0 += 1 }
        if let error { throw error }
        return samples
    }
}

final class FakeSleepRepository: SleepRepository, @unchecked Sendable {
    /// "yyyy-MM-dd" → 응답. 없으면 noData.
    @Locked var summaryByDate: [String: SleepSummaryResponse] = [:]
    @Locked private(set) var uploads: [UploadSleepSamplesRequest] = []
    @Locked private(set) var summaryDates: [String] = []

    func uploadSamples(_ req: UploadSleepSamplesRequest) async throws -> UploadSleepSamplesResponse {
        $uploads.mutate { $0.append(req) }
        return UploadSleepSamplesResponse(received: req.samples.count, inserted: req.samples.count)
    }

    func summary(date: String, timeZone: TimeZone) async throws -> SleepSummaryResponse {
        $summaryDates.mutate { $0.append(date) }
        return summaryByDate[date] ?? .noData
    }
}
