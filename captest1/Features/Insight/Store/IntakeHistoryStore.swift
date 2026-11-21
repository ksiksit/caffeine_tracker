//
//  IntakeHistoryStore.swift
//  captest1
//
//  주간 섭취 히스토리 화면(로드맵 §2 (11)). 서버 기간별 섭취 통계를 그대로 보관한다 — 총량·평균·문장을 앱에서 다시 계산하지 않는다.
//  기간은 섭취일 기준 오늘까지 7일로 고정이다. 화면에 들어올 때마다 다시 받는다(홈에서 기록을 고치고 다시 들어오는 경우).
//

import Foundation

@MainActor
@Observable
final class IntakeHistoryStore {
    /// 화면이 그릴 상태. 실패를 "기록 없음"처럼 보이게 하지 않으려고 넷을 구분한다.
    enum Phase {
        case loading
        case failed(message: String)
        /// 기간 안에 기록이 있는 날이 하나도 없다(서버 recordedDayCount == 0)
        case empty(IntakeStatsResponse)
        case loaded(IntakeStatsResponse)
    }

    /// 보여 주는 날 수(섭취일 기준 오늘 포함). 서버 기간 검증(31일 이하) 안.
    nonisolated static let dayCount = 7

    private(set) var stats: IntakeStatsResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// 보여 주는 통계가 마지막 조회로 확인되지 않은 값인가(조회 실패 뒤 같은 기간의 이전 값을 유지). 화면은 `loadedAt` 기준이라고 알린다.
    private(set) var isStale = false
    /// 마지막으로 조회에 성공한 기기 시각("N분 전 기준")
    private(set) var loadedAt: Date?

    /// `stats`를 받을 때 요청한 기간
    @ObservationIgnored private var loadedRange: DateRange?
    /// 조회 중에 다시 받으라는 요청이 오면(당겨서 새로고침 등) 끝난 뒤 한 번 더 받는다.
    @ObservationIgnored private var rerunRequested = false

    private let repository: any IntakeStatsRepository
    @ObservationIgnored private let clock: () -> Date

    init(repository: any IntakeStatsRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.clock = now
    }

    var phase: Phase {
        if let stats {
            return stats.recordedDayCount == 0 ? .empty(stats) : .loaded(stats)
        }
        if !isLoading, let errorMessage {
            return .failed(message: errorMessage)
        }
        return .loading
    }

    /// 최근 날이 위로 오는 순서. 서버 days(오름차순)를 뒤집기만 한다.
    var daysNewestFirst: [IntakeStatsDayDTO] {
        stats?.days.reversed() ?? []
    }

    // MARK: - 조회

    func refresh() async {
        guard !isLoading else {
            rerunRequested = true
            return
        }
        isLoading = true
        repeat {
            rerunRequested = false
            await fetch()
        } while rerunRequested
        isLoading = false
    }

    private func fetch() async {
        let range = Self.range(endingOn: clock())
        // 날이 바뀌어 기간이 달라졌으면 이전 기간의 통계를 새 기간 것처럼 보여 주지 않는다.
        if loadedRange != range {
            clearStats()
        }
        do {
            stats = try await repository.intakeStats(from: range.from, to: range.to, timeZone: .current)
            loadedRange = range
            errorMessage = nil
            isStale = false
            loadedAt = clock()
        } catch is CancellationError {
            // 화면 전환으로 취소된 요청은 실패가 아니다
        } catch {
            errorMessage = "섭취 히스토리를 불러오지 못했어요. 서버 연결을 확인해주세요."
            // 같은 기간의 이전 통계는 "N분 전 기준"으로 남긴다(홈 today 캐시와 같은 방식).
            isStale = stats != nil
        }
    }

    /// 로그아웃 시 이전 계정의 값을 지운다.
    func reset() {
        clearStats()
        isLoading = false
        errorMessage = nil
        rerunRequested = false
    }

    private func clearStats() {
        stats = nil
        loadedRange = nil
        isStale = false
        loadedAt = nil
    }

    // MARK: - 요청 기간

    struct DateRange: Equatable {
        let from: String
        let to: String
    }

    /// 섭취일 기준 오늘까지 `count`일. 섭취일은 새벽 5시에 바뀌므로(홈의 오늘과 같다) 00:00~05:00에는 달력 전날이 오늘이다.
    /// 달력 날짜보다 늦지 않아 서버 `to ≤ 오늘` 검증을 통과한다. 통계 자체는 서버가 계산한다 — 여기서는 요청 날짜만 정한다.
    static func range(endingOn now: Date, count: Int = dayCount, calendar: Calendar = .current) -> DateRange {
        let boundary = AppConstants.Pharmacokinetics.chartStartHour
        let intakeToday = calendar.date(byAdding: .hour, value: -boundary, to: now) ?? now
        let first = calendar.date(byAdding: .day, value: -(count - 1), to: intakeToday) ?? intakeToday
        let formatter = ServerDateCoding.localDate
        return DateRange(from: formatter.string(from: first), to: formatter.string(from: intakeToday))
    }
}
