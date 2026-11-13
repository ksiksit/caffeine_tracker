//
//  InsightStore.swift
//  captest1
//
//  수면 탭의 밤별 카페인(로드맵 §2 (1)·(6)). 서버 카페인·수면 리포트의 nights를 그대로 보관한다 — 잔량·SOL을 앱에서 다시 계산하지 않는다.
//  리포트는 업로드된 수면 샘플로 계산되므로 수면 업로드가 끝난 뒤와 카페인 기록이 바뀐 뒤에 다시 받는다(조립은 ContentView).
//

import Foundation

@MainActor
@Observable
final class InsightStore {
    /// 수면 탭에 보여 주는 밤 수(오늘 아침에 끝난 밤 포함). 서버 기간 검증(31일 이하) 안.
    static let recentNightCount = 7
    /// 이 시간이 지나면 탭 진입에서 다시 받는다(SleepStore와 같은 기준).
    private static let maxLoadAge: TimeInterval = 3600

    private(set) var report: CaffeineSleepReportResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// 보여 주는 리포트가 마지막 조회로 확인되지 않은 값인가(조회 실패 뒤 이전 값을 유지). 화면은 `loadedAt` 기준이라고 알린다.
    private(set) var isStale = false
    /// 마지막으로 조회에 성공한 기기 시각("N분 전 기준")
    private(set) var loadedAt: Date?
    /// 요청한 아침 날짜("yyyy-MM-dd") 오름차순. 응답에 없는 날짜는 "데이터 없음"으로 그린다.
    private(set) var nightKeys: [String] = []

    @ObservationIgnored private var isInvalidated = false
    /// 조회 중에 다시 받으라는 요청이 오면(예: 수면 업로드 완료) 끝난 뒤 한 번 더 받는다.
    @ObservationIgnored private var rerunRequested = false

    private let repository: any InsightRepository
    @ObservationIgnored private let clock: () -> Date

    init(repository: any InsightRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.clock = now
    }

    // MARK: - 조회

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

    /// 다음 진입 때 다시 받도록 표시한다(카페인 기록이 바뀌면 취침 잔량이 바뀐다).
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
        let keys = Self.nightKeys(endingOn: clock())
        guard let from = keys.first, let to = keys.last else { return }
        do {
            report = try await repository.caffeineSleepReport(from: from, to: to, timeZone: .current)
            nightKeys = keys
            errorMessage = nil
            isStale = false
            loadedAt = clock()
            isInvalidated = false
        } catch is CancellationError {
            // 화면 전환으로 취소된 요청은 실패가 아니다
        } catch {
            errorMessage = "카페인 기록과 함께 보려면 서버 연결이 필요해요."
            // 같은 기간의 이전 리포트는 "N분 전 기준"으로 남긴다(홈 today 캐시와 같은 방식).
            // 날이 바뀌어 기간이 달라졌으면 버린다 — 실패를 "데이터 없음"처럼 보이게 하지 않는다.
            if report != nil, nightKeys == keys {
                isStale = true
            } else {
                report = nil
                nightKeys = []
                isStale = false
                loadedAt = nil
            }
        }
    }

    /// 로그아웃 시 이전 계정의 값을 지운다.
    func reset() {
        report = nil
        nightKeys = []
        isLoading = false
        errorMessage = nil
        isStale = false
        loadedAt = nil
        isInvalidated = false
        rerunRequested = false
    }

    // MARK: - 표시용 조회(서버 값 그대로)

    /// 비교 A 경계(서버 값). 리포트가 없으면 nil.
    var residualThresholdMg: Double? { report?.residualThresholdMg }

    /// 아침 날짜 `date`에 끝난 밤. 리포트에 그 밤이 없으면 nil.
    func night(endingOn date: Date) -> InsightNightDTO? {
        let key = ServerDateCoding.localDate.string(from: date)
        return report?.nights.first { $0.date == key }
    }

    /// 요청한 날짜마다 서버 밤(없으면 nil). 날짜 오름차순.
    var recentNights: [(key: String, night: InsightNightDTO?)] {
        guard let report else { return [] }
        let byDate = Dictionary(report.nights.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        return nightKeys.map { ($0, byDate[$0]) }
    }

    /// 오늘 아침까지 최근 N일의 아침 날짜 키. 서버 `to ≤ 오늘` 검증과 같은 기기 타임존으로 만든다.
    static func nightKeys(endingOn now: Date, count: Int = recentNightCount, calendar: Calendar = .current) -> [String] {
        (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map { ServerDateCoding.localDate.string(from: $0) }
        }
    }
}
