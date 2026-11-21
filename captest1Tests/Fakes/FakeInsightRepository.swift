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
    /// true면 호출이 바로 끝나지 않고 `release(_:)`를 기다린다(요청이 떠 있는 동안의 동작을 테스트할 때). 기본은 즉시 `result` 반환.
    @Locked var holdsResponses = false
    @Locked private var held: [CheckedContinuation<Result<CaffeineSleepReportResponse, Error>, Never>] = []

    func caffeineSleepReport(from: String, to: String, timeZone: TimeZone) async throws -> CaffeineSleepReportResponse {
        $requests.mutate { $0.append((from, to)) }
        guard holdsResponses else { return try result.get() }
        let outcome = await withCheckedContinuation { continuation in
            $held.mutate { $0.append(continuation) }
        }
        return try outcome.get()
    }

    /// 붙잡힌 요청이 `count`개가 될 때까지 기다린다. 끝내 안 되면(약 2초) false.
    func waitForHeldRequests(_ count: Int) async -> Bool {
        for _ in 0..<2000 {
            if held.count >= count { return true }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return held.count >= count
    }

    /// 가장 먼저 붙잡힌 요청에 응답을 돌려준다.
    func release(_ outcome: Result<CaffeineSleepReportResponse, Error>) {
        var continuation: CheckedContinuation<Result<CaffeineSleepReportResponse, Error>, Never>?
        $held.mutate { if !$0.isEmpty { continuation = $0.removeFirst() } }
        continuation?.resume(returning: outcome)
    }
}

extension CaffeineSleepReportResponse {
    static func fixture(nights: [InsightNightDTO] = [], threshold: Double = 50,
                        residualComparison: InsightComparisonDTO = .fixture(),
                        cutoffComparison: InsightComparisonDTO = .fixture(),
                        headlines: [String] = []) -> CaffeineSleepReportResponse {
        CaffeineSleepReportResponse(
            from: nights.first?.date ?? "2027-01-09", to: nights.last?.date ?? "2027-01-15",
            nightCount: nights.count, sufficient: nights.count >= 5,
            residualThresholdMg: threshold, halfLifeHoursUsed: 5,
            residualComparison: residualComparison, cutoffComparison: cutoffComparison,
            headlines: headlines, nights: nights)
    }
}

extension InsightComparisonDTO {
    static func fixture(high: InsightGroupDTO = .fixture(), low: InsightGroupDTO = .fixture(),
                        sufficient: Bool = false, moreNightsNeeded: Int? = 6,
                        solDiffMinutes: Double? = nil, efficiencyDiff: Double? = nil,
                        sentence: String = "") -> InsightComparisonDTO {
        InsightComparisonDTO(high: high, low: low, sufficient: sufficient, moreNightsNeeded: moreNightsNeeded,
                             solDiffMinutes: solDiffMinutes, efficiencyDiff: efficiencyDiff, sentence: sentence)
    }
}

extension InsightGroupDTO {
    static func fixture(nightCount: Int = 0, solNightCount: Int = 0, avgSol: Double? = nil, avgEfficiency: Double? = nil,
                        avgTotalSleep: Double? = nil, avgDeep: Double? = nil) -> InsightGroupDTO {
        InsightGroupDTO(nightCount: nightCount, solNightCount: solNightCount, avgSolMinutes: avgSol,
                        avgSleepEfficiency: avgEfficiency, avgTotalSleepMinutes: avgTotalSleep, avgDeepSleepRatio: avgDeep)
    }
}

extension InsightNightDTO {
    static func fixture(date: String, residual: Double = 0, dayTotal: Double = 0, sol: Double? = nil) -> InsightNightDTO {
        InsightNightDTO(date: date, bedtime: Date(timeIntervalSince1970: 1_800_000_000),
                        residualAtBedtimeMg: residual, dayTotalMg: dayTotal, lastIntakeAt: nil, cutoffKept: nil,
                        solMinutes: sol, sleepEfficiency: 0.9, totalSleepMinutes: 420, deepSleepRatio: nil)
    }
}
