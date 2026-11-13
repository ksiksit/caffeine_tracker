//
//  FakeInsightRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeInsightRepository: InsightRepository, @unchecked Sendable {
    @Locked var result: Result<CaffeineSleepReportResponse, Error> = .success(.fixture())
    /// 요청 기록: (from, to)
    @Locked private(set) var requests: [(from: String, to: String)] = []

    func caffeineSleepReport(from: String, to: String, timeZone: TimeZone) async throws -> CaffeineSleepReportResponse {
        $requests.mutate { $0.append((from, to)) }
        return try result.get()
    }
}

extension CaffeineSleepReportResponse {
    static func fixture(nights: [InsightNightDTO] = [], threshold: Double = 50) -> CaffeineSleepReportResponse {
        let group = InsightGroupDTO(nightCount: 0, solNightCount: 0, avgSolMinutes: nil,
                                    avgSleepEfficiency: nil, avgTotalSleepMinutes: nil, avgDeepSleepRatio: nil)
        let comparison = InsightComparisonDTO(high: group, low: group, sufficient: false, moreNightsNeeded: 6,
                                              solDiffMinutes: nil, efficiencyDiff: nil, sentence: "")
        return CaffeineSleepReportResponse(
            from: nights.first?.date ?? "2027-01-09", to: nights.last?.date ?? "2027-01-15",
            nightCount: nights.count, sufficient: nights.count >= 5,
            residualThresholdMg: threshold, halfLifeHoursUsed: 5,
            residualComparison: comparison, cutoffComparison: comparison,
            headlines: [], nights: nights)
    }
}

extension InsightNightDTO {
    static func fixture(date: String, residual: Double = 0, dayTotal: Double = 0, sol: Double? = nil) -> InsightNightDTO {
        InsightNightDTO(date: date, bedtime: Date(timeIntervalSince1970: 1_800_000_000),
                        residualAtBedtimeMg: residual, dayTotalMg: dayTotal, lastIntakeAt: nil, cutoffKept: nil,
                        solMinutes: sol, sleepEfficiency: 0.9, totalSleepMinutes: 420, deepSleepRatio: nil)
    }
}
