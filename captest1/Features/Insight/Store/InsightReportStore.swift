//
//  InsightReportStore.swift
//  captest1
//
//  카페인·수면 상관 리포트 화면(로드맵 §3.1). 고른 기간의 서버 리포트를 그대로 보관한다 — 비교·문장을 앱에서 다시 계산하지 않는다.
//  수면 탭의 밤별 카드(InsightStore, 최근 7밤 고정)와 기간이 달라 따로 둔다.
//

import Foundation

@MainActor
@Observable
final class InsightReportStore {
    /// 화면이 그릴 상태. 실패를 "데이터 없음"처럼 보이게 하지 않으려고 넷을 구분한다.
    enum Phase {
        case loading
        case failed(message: String)
        /// 기간 안에 리포트에 들어간 밤이 하나도 없다(서버 nightCount == 0)
        case empty(CaffeineSleepReportResponse)
        case loaded(CaffeineSleepReportResponse)
    }

    /// 이 시간이 지나면 화면 진입에서 다시 받는다(InsightStore와 같은 기준).
    private static let maxLoadAge: TimeInterval = 3600

    private(set) var period: InsightReportPeriod = .default
    private(set) var report: CaffeineSleepReportResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// 보여 주는 리포트가 마지막 조회로 확인되지 않은 값인가(조회 실패 뒤 같은 기간의 이전 값을 유지).
    private(set) var isStale = false
    /// 마지막으로 조회에 성공한 기기 시각("N분 전 기준")
    private(set) var loadedAt: Date?

    /// `report`를 받을 때 요청한 기간
    @ObservationIgnored private var loadedRange: ClosedRange<String>?
    @ObservationIgnored private var isInvalidated = false
    /// 조회 중에 다시 받으라는 요청이 오면(기간 변경 등) 끝난 뒤 한 번 더 받는다.
    @ObservationIgnored private var rerunRequested = false

    private let repository: any InsightRepository
    @ObservationIgnored private let clock: () -> Date

    init(repository: any InsightRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.clock = now
    }

    var phase: Phase {
        if let report {
            return report.nightCount == 0 ? .empty(report) : .loaded(report)
        }
        if !isLoading, let errorMessage {
            return .failed(message: errorMessage)
        }
        return .loading
    }

    // MARK: - 조회

    /// 기간을 바꾸고 그 기간으로 다시 받는다. 다른 기간의 리포트를 새 기간 것처럼 보여 주지 않도록 먼저 비운다.
    func select(_ newPeriod: InsightReportPeriod) async {
        guard newPeriod != period else { return }
        period = newPeriod
        clearReport()
        errorMessage = nil
        await refresh()
    }

    /// 처음이거나, 지난 조회가 실패했거나, 기록이 바뀌었거나, 날이 바뀌었거나, 오래됐으면 다시 받는다.
    func refreshIfNeeded() async {
        let now = clock()
        if let loadedAt, !isInvalidated, !isStale, errorMessage == nil,
           now.timeIntervalSince(loadedAt) < Self.maxLoadAge,
           Calendar.current.isDate(loadedAt, inSameDayAs: now) {
            return
        }
        await refresh()
    }

    /// 다음 진입 때 다시 받도록 표시한다(카페인 기록이나 수면 업로드가 바뀌면 비교가 바뀐다).
    func invalidate() {
        isInvalidated = true
    }

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
        let requested = period
        let keys = InsightStore.nightKeys(endingOn: clock(), count: requested.days)
        guard let from = keys.first, let to = keys.last else { return }
        let range = from...to
        do {
            let response = try await repository.caffeineSleepReport(from: from, to: to, timeZone: .current)
            // 기다리는 동안 기간이 바뀌었으면 버린다 — 바뀐 기간으로 다시 받는 중이다.
            guard requested == period else { return }
            report = response
            loadedRange = range
            errorMessage = nil
            isStale = false
            loadedAt = clock()
            isInvalidated = false
        } catch is CancellationError {
            // 화면 전환으로 취소된 요청은 실패가 아니다
        } catch {
            guard requested == period else { return }
            errorMessage = "리포트를 불러오려면 서버 연결이 필요해요."
            // 같은 기간의 이전 리포트는 "N분 전 기준"으로 남긴다. 날이 바뀌어 기간이 달라졌으면 버린다.
            if report != nil, loadedRange == range {
                isStale = true
            } else {
                clearReport()
            }
        }
    }

    private func clearReport() {
        report = nil
        loadedRange = nil
        isStale = false
        loadedAt = nil
    }

    /// 로그아웃 시 이전 계정의 값을 지운다.
    func reset() {
        period = .default
        clearReport()
        isLoading = false
        errorMessage = nil
        isInvalidated = false
        rerunRequested = false
    }
}
