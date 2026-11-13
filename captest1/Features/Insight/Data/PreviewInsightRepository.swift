//
//  PreviewInsightRepository.swift
//  captest1
//
//  #Preview용 인사이트 페이크: 최근 7일 중 5밤이 있는 리포트를 흉내 낸다(값은 화면 확인용).
//

#if DEBUG
import Foundation

nonisolated struct PreviewInsightRepository: InsightRepository {
    func caffeineSleepReport(from: String, to: String, timeZone: TimeZone) async throws -> CaffeineSleepReportResponse {
        let formatter = ServerDateCoding.localDate
        let end = formatter.date(from: to) ?? Date()
        let samples: [(offset: Int, residual: Double, total: Double, sol: Double?)] = [
            (5, 12.4, 150, 11), (4, 74.8, 300, 32), (3, 0, 0, 9), (1, 51.2, 225, nil), (0, 38.6, 150, 18),
        ]
        let nights = samples.reversed().map { s -> InsightNightDTO in
            let day = Calendar.current.date(byAdding: .day, value: -s.offset, to: end) ?? end
            return InsightNightDTO(
                date: formatter.string(from: day),
                bedtime: day.addingTimeInterval(-7 * 3600),
                residualAtBedtimeMg: s.residual,
                dayTotalMg: s.total,
                lastIntakeAt: s.total > 0 ? day.addingTimeInterval(-14 * 3600) : nil,
                cutoffKept: s.total > 0 ? s.residual < 50 : nil,
                solMinutes: s.sol,
                sleepEfficiency: 0.9,
                totalSleepMinutes: 420,
                deepSleepRatio: 0.15
            )
        }
        let group = InsightGroupDTO(nightCount: 0, solNightCount: 0, avgSolMinutes: nil,
                                    avgSleepEfficiency: nil, avgTotalSleepMinutes: nil, avgDeepSleepRatio: nil)
        let comparison = InsightComparisonDTO(high: group, low: group, sufficient: false, moreNightsNeeded: 1,
                                              solDiffMinutes: nil, efficiencyDiff: nil, sentence: "")
        return CaffeineSleepReportResponse(
            from: from, to: to, nightCount: nights.count, sufficient: true,
            residualThresholdMg: 50, halfLifeHoursUsed: 5,
            residualComparison: comparison, cutoffComparison: comparison,
            headlines: [], nights: nights
        )
    }
}
#endif
