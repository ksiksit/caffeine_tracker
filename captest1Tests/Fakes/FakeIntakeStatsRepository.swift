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
    /// true면 응답을 바로 주지 않고 `release`가 불릴 때까지 붙잡아 둔다(요청이 떠 있는 동안의 동작을 볼 때).
    @Locked var holdsResponses = false
    @Locked private var pending: [CheckedContinuation<IntakeStatsResponse, Error>] = []

    func intakeStats(from: String, to: String, timeZone: TimeZone) async throws -> IntakeStatsResponse {
        $requests.mutate { $0.append((from, to)) }
        guard holdsResponses else { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation in
            $pending.mutate { $0.append(continuation) }
        }
    }

    /// 붙잡아 둔 요청 수
    var pendingCount: Int { pending.count }

    /// 붙잡아 둔 요청이 `count`개가 될 때까지 기다린다. 끝내 안 되면 false(테스트가 멈추지 않게 2초 한도).
    func waitForPending(_ count: Int) async -> Bool {
        for _ in 0..<2000 {
            if pendingCount == count { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return pendingCount == count
    }

    /// 가장 먼저 붙잡힌 요청에 응답을 준다.
    func release(_ result: Result<IntakeStatsResponse, Error>) {
        var continuation: CheckedContinuation<IntakeStatsResponse, Error>?
        $pending.mutate { continuation = $0.isEmpty ? nil : $0.removeFirst() }
        continuation?.resume(with: result)
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
