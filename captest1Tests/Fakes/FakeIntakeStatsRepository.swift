//
//  FakeIntakeStatsRepository.swift
//  captest1Tests
//

import Foundation
@testable import captest1

final class FakeIntakeStatsRepository: IntakeStatsRepository, @unchecked Sendable {
    @Locked var result: Result<IntakeStatsResponse, Error> = .success(.fixture())
    /// 요청 기록: (from, to)
    @Locked private(set) var requests: [(from: String, to: String)] = []

    func intakeStats(from: String, to: String, timeZone: TimeZone) async throws -> IntakeStatsResponse {
        $requests.mutate { $0.append((from, to)) }
        return try result.get()
    }
}

extension IntakeStatsResponse {
    /// 요약 값은 서버가 주는 것이라 days에서 계산하지 않고 인자로 받는다.
    static func fixture(days: [IntakeStatsDayDTO] = [], recordedDayCount: Int? = nil,
                        average: Double? = nil, max: Double? = nil, overLimitDayCount: Int = 0,
                        sentence: String = "최근 7일 하루 평균을 낼 섭취 기록이 아직 없어요.") -> IntakeStatsResponse {
        IntakeStatsResponse(
            from: days.first?.date ?? "2027-01-09", to: days.last?.date ?? "2027-01-15",
            dayCount: days.count, recordedDayCount: recordedDayCount ?? days.filter { $0.recordCount > 0 }.count,
            averageDailyMg: average, maxDailyMg: max, overLimitDayCount: overLimitDayCount,
            averageLastIntakeMinuteOfDay: nil, summarySentence: sentence, days: days)
    }
}

extension IntakeStatsDayDTO {
    static func fixture(date: String, total: Double = 0, count: Int = 0, last: Date? = nil,
                        overLimit: Bool = false) -> IntakeStatsDayDTO {
        IntakeStatsDayDTO(date: date, totalMg: total, recordCount: count, firstIntakeAt: last, lastIntakeAt: last,
                          overLimit: overLimit)
    }
}
