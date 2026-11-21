//
//  PreviewInsightRepository.swift
//  captest1
//
//  #Preview용 인사이트 페이크: 요청 기간의 마지막 7일 중 5밤이 있는 리포트를 흉내 낸다(값은 화면 확인용).
//  비교 A는 표본이 충분한 경우, 비교 B는 밤이 모자란 경우를 한 화면에서 볼 수 있게 고정값으로 둔다.
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
        let residualSentence = "취침 때 카페인이 50mg 이상 남아 있던 밤은 잠드는 데 평균 11분 더 걸렸고, 수면 효율은 4%p 낮았어요 (5밤 vs 7밤)"
        let residual = InsightComparisonDTO(
            high: InsightGroupDTO(nightCount: 5, solNightCount: 5, avgSolMinutes: 27, avgSleepEfficiency: 0.86,
                                  avgTotalSleepMinutes: 402, avgDeepSleepRatio: 0.14),
            low: InsightGroupDTO(nightCount: 7, solNightCount: 7, avgSolMinutes: 16, avgSleepEfficiency: 0.9,
                                 avgTotalSleepMinutes: 431, avgDeepSleepRatio: 0.17),
            sufficient: true, moreNightsNeeded: nil, solDiffMinutes: 11, efficiencyDiff: -0.04,
            sentence: residualSentence)
        let cutoff = InsightComparisonDTO(
            high: InsightGroupDTO(nightCount: 2, solNightCount: 2, avgSolMinutes: 30, avgSleepEfficiency: 0.85,
                                  avgTotalSleepMinutes: 395, avgDeepSleepRatio: 0.13),
            low: InsightGroupDTO(nightCount: 8, solNightCount: 8, avgSolMinutes: 18, avgSleepEfficiency: 0.89,
                                 avgTotalSleepMinutes: 425, avgDeepSleepRatio: 0.16),
            sufficient: false, moreNightsNeeded: 1, solDiffMinutes: nil, efficiencyDiff: nil,
            sentence: "지금 기준 용량(75mg)으로 따지면, 마감을 넘긴 밤이 1밤 더 있어야 비교할 수 있어요")
        return CaffeineSleepReportResponse(
            from: from, to: to, nightCount: nights.count, sufficient: true,
            residualThresholdMg: 50, halfLifeHoursUsed: 5,
            residualComparison: residual, cutoffComparison: cutoff,
            headlines: [residualSentence], nights: nights
        )
    }
}
#endif
