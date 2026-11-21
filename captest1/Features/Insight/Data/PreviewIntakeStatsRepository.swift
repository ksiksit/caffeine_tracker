//
//  PreviewIntakeStatsRepository.swift
//  captest1
//
//  #Preview용 섭취 통계 페이크: 요청 기간의 마지막 7일을 흉내 낸다(값은 화면 확인용, 문장은 서버 형식 그대로).
//

#if DEBUG
import Foundation

nonisolated struct PreviewIntakeStatsRepository: IntakeStatsRepository {
    /// true면 기간 안에 기록이 하나도 없는 응답을 낸다.
    var empty = false

    func intakeStats(from: String, to: String, timeZone: TimeZone) async throws -> IntakeStatsResponse {
        let formatter = ServerDateCoding.localDate
        let end = formatter.date(from: to) ?? Date()
        // (며칠 전, 총량, 기록 수, 마지막 섭취 시각의 시)
        let samples: [(offset: Int, total: Double, count: Int, lastHour: Int)] = empty ? [] : [
            (6, 150, 1, 9), (5, 420, 3, 17), (4, 0, 0, 0), (3, 225, 2, 15), (2, 300, 2, 16), (1, 75, 1, 10), (0, 150, 1, 8),
        ]
        let byOffset = Dictionary(samples.map { ($0.offset, $0) }, uniquingKeysWith: { first, _ in first })
        let days = (0..<7).reversed().map { offset -> IntakeStatsDayDTO in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: end) ?? end
            let sample = byOffset[offset]
            let hasRecords = (sample?.count ?? 0) > 0
            return IntakeStatsDayDTO(
                date: formatter.string(from: day),
                totalMg: sample?.total ?? 0,
                recordCount: sample?.count ?? 0,
                firstIntakeAt: hasRecords ? day.addingTimeInterval(8 * 3600) : nil,
                lastIntakeAt: hasRecords ? day.addingTimeInterval(Double(sample?.lastHour ?? 0) * 3600) : nil,
                overLimit: (sample?.total ?? 0) > 400
            )
        }
        return IntakeStatsResponse(
            from: from, to: to, dayCount: days.count, recordedDayCount: empty ? 0 : 6,
            averageDailyMg: empty ? nil : 234, maxDailyMg: empty ? nil : 420,
            overLimitDayCount: empty ? 0 : 1, averageLastIntakeMinuteOfDay: empty ? nil : 804,
            summarySentence: empty
                ? "최근 7일 하루 평균을 낼 섭취 기록이 아직 없어요."
                : "최근 7일 하루 평균 234mg, 400mg을 넘긴 날은 1일이에요. 마지막 한 잔은 평균 13시 24분이에요.",
            days: days
        )
    }
}
#endif
