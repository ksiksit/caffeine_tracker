//
//  InsightReportStoreTests.swift
//  captest1Tests
//
//  카페인·수면 리포트 화면: 기간별 요청 범위, 화면 상태(불러오는 중·실패·밤 없음·표시), 실패 뒤 이전 값 유지,
//  비교 카드 표시 형식(서버 값 그대로·값 없음·필요한 밤 수). 네트워크 대신 FakeInsightRepository.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct InsightReportStoreTests {
    /// 기기 타임존의 2027-01-15 정오(1시간 안팎을 더해도 날짜가 바뀌지 않는 시각)
    private let noon = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))!
    private let fiveNights: [InsightNightDTO] = (11...15).map { .fixture(date: "2027-01-\($0)") }

    // MARK: - 요청 기간

    @Test func refresh_requestsDefaultFourteenDays_endingToday() async {
        let repo = FakeInsightRepository()
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.refresh()
        #expect(store.period == .twoWeeks)
        #expect(repo.requests.count == 1)
        #expect(repo.requests.first?.from == "2027-01-02")
        #expect(repo.requests.first?.to == "2027-01-15")
    }

    @Test func select_requestsThatPeriod_withinServerLimit() async {
        let repo = FakeInsightRepository()
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.select(.month)
        #expect(repo.requests.last?.from == "2026-12-17")
        #expect(repo.requests.last?.to == "2027-01-15")
        await store.select(.week)
        #expect(repo.requests.last?.from == "2027-01-09")
        // 서버 기간 검증: 31일 이하
        #expect(InsightReportPeriod.allCases.allSatisfy { $0.days <= 31 })
    }

    @Test func select_samePeriod_doesNotRefetch() async {
        let repo = FakeInsightRepository()
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.refresh()
        await store.select(.twoWeeks)
        #expect(repo.requests.count == 1)
    }

    // MARK: - 화면 상태

    @Test func phase_beforeFirstLoad_isLoading() {
        let store = InsightReportStore(repository: FakeInsightRepository(), now: { noon })
        guard case .loading = store.phase else {
            Issue.record("처음에는 불러오는 중이어야 한다: \(store.phase)")
            return
        }
    }

    @Test func phase_loaded_keepsServerSentencesAndComparisons() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(
            nights: fiveNights,
            residualComparison: .fixture(sufficient: true, moreNightsNeeded: nil, sentence: "잔량 문장"),
            cutoffComparison: .fixture(sufficient: false, moreNightsNeeded: 2, sentence: "마감 문장"),
            headlines: ["요약 1", "요약 2"]))
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.refresh()
        guard case .loaded(let report) = store.phase else {
            Issue.record("리포트가 보여야 한다: \(store.phase)")
            return
        }
        #expect(report.headlines == ["요약 1", "요약 2"])
        #expect(report.residualComparison.sentence == "잔량 문장")
        #expect(report.cutoffComparison.sentence == "마감 문장")
        #expect(report.cutoffComparison.moreNightsNeeded == 2)
    }

    @Test func phase_noNights_isEmpty_notFailure() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(nights: [], headlines: ["리포트를 보려면 수면 기록이 있는 밤이 5밤 더 필요해요"]))
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.refresh()
        guard case .empty(let report) = store.phase else {
            Issue.record("밤이 없으면 데이터 없음이어야 한다: \(store.phase)")
            return
        }
        #expect(report.headlines.first == "리포트를 보려면 수면 기록이 있는 밤이 5밤 더 필요해요")
        #expect(store.errorMessage == nil)
    }

    @Test func phase_failureWithoutPrevious_isFailed_notEmpty() async {
        let repo = FakeInsightRepository()
        repo.result = .failure(FakeError())
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.refresh()
        guard case .failed(let message) = store.phase else {
            Issue.record("실패는 데이터 없음과 구분해야 한다: \(store.phase)")
            return
        }
        #expect(!message.isEmpty)
        #expect(store.report == nil)
        #expect(store.isStale == false)
    }

    // MARK: - 실패·재조회

    @Test func failure_afterSuccess_keepsSamePeriodReportAsStale() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(nights: fiveNights, headlines: ["요약"]))
        var now = noon
        let store = InsightReportStore(repository: repo, now: { now })
        await store.refresh()

        now = noon.addingTimeInterval(10 * 60)
        repo.result = .failure(FakeError())
        await store.refresh()
        #expect(store.report?.headlines == ["요약"])
        #expect(store.isStale)
        #expect(store.loadedAt == noon)
        guard case .loaded = store.phase else {
            Issue.record("이전 리포트를 계속 보여야 한다: \(store.phase)")
            return
        }

        repo.result = .success(.fixture(nights: fiveNights))
        await store.refresh()
        #expect(store.isStale == false)
        #expect(store.errorMessage == nil)
    }

    @Test func failure_afterPeriodChange_doesNotShowOtherPeriodReport() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(nights: fiveNights))
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.refresh()

        repo.result = .failure(FakeError())
        await store.select(.month)
        #expect(store.report == nil)
        #expect(store.isStale == false)
        guard case .failed = store.phase else {
            Issue.record("14일 리포트를 30일 것처럼 보이면 안 된다: \(store.phase)")
            return
        }
    }

    @Test func failure_afterDayChange_dropsPreviousPeriod() async {
        let repo = FakeInsightRepository()
        var now = noon
        let store = InsightReportStore(repository: repo, now: { now })
        await store.refresh()

        now = noon.addingTimeInterval(86_400)
        repo.result = .failure(FakeError())
        await store.refresh()
        #expect(store.report == nil)
        #expect(store.loadedAt == nil)
    }

    @Test func refreshIfNeeded_skipsWhenFresh_refetchesWhenInvalidatedOrOldOrFailed() async {
        let repo = FakeInsightRepository()
        var now = noon
        let store = InsightReportStore(repository: repo, now: { now })
        await store.refreshIfNeeded()
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 1)

        store.invalidate()
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 2)

        now = noon.addingTimeInterval(3601)
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 3)

        repo.result = .failure(FakeError())
        await store.refresh()
        repo.result = .success(.fixture())
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 5)
        #expect(store.isStale == false)
    }

    @Test func reset_clearsEverything_andReturnsToDefaultPeriod() async {
        let repo = FakeInsightRepository()
        let store = InsightReportStore(repository: repo, now: { noon })
        await store.select(.week)
        store.reset()
        #expect(store.report == nil)
        #expect(store.period == .default)
        #expect(store.errorMessage == nil)
        #expect(store.loadedAt == nil)
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 2)
    }

    // MARK: - 비교 카드 표시

    @Test func comparisonDisplay_showsServerGroupValues_roundedOnly() {
        let comparison = InsightComparisonDTO.fixture(
            high: .fixture(nightCount: 5, solNightCount: 5, avgSol: 27.4, avgEfficiency: 0.856, avgTotalSleep: 402, avgDeep: 0.14),
            low: .fixture(nightCount: 7, solNightCount: 7, avgSol: 16, avgEfficiency: 0.9, avgTotalSleep: 431.6, avgDeep: 0.17),
            sufficient: true, moreNightsNeeded: nil, sentence: "서버 문장")
        let display = InsightComparisonDisplay(kind: .residual(thresholdMg: 50), comparison: comparison)

        #expect(display.sentence == "서버 문장")
        #expect(display.shortageText == nil)
        #expect(display.rows.map(\.label) == ["밤 수", "잠들기까지", "수면 효율", "총 수면", "깊은 수면"])
        #expect(display.rows.map(\.high) == ["5밤", "27분", "86%", "6시간 42분", "14%"])
        #expect(display.rows.map(\.low) == ["7밤", "16분", "90%", "7시간 12분", "17%"])
    }

    @Test func comparisonDisplay_residualLabels_useServerThreshold() {
        let display = InsightComparisonDisplay(kind: .residual(thresholdMg: 60), comparison: .fixture())
        #expect(display.highLabel == "60mg 이상")
        #expect(display.lowLabel == "60mg 미만")
        let cutoff = InsightComparisonDisplay(kind: .cutoff, comparison: .fixture())
        #expect(cutoff.highLabel == "마감 넘김")
        #expect(cutoff.lowLabel == "마감 지킴")
    }

    @Test func comparisonDisplay_insufficient_showsMoreNightsNeeded() {
        let display = InsightComparisonDisplay(kind: .cutoff, comparison: .fixture(sufficient: false, moreNightsNeeded: 2))
        #expect(display.shortageText == "비교하려면 2밤이 더 필요해요")
        // 밤 수가 오지 않아도 표본 부족은 알린다
        let unknown = InsightComparisonDisplay(kind: .cutoff, comparison: .fixture(sufficient: false, moreNightsNeeded: nil))
        #expect(unknown.shortageText != nil)
    }

    @Test func comparisonDisplay_missingAverages_showDash_notZero() {
        // 그룹에 밤이 없거나 SOL이 없으면 서버가 null을 준다 — 0으로 보이면 안 된다
        let display = InsightComparisonDisplay(kind: .cutoff, comparison: .fixture(
            high: .fixture(nightCount: 0), low: .fixture(nightCount: 3, avgEfficiency: 0.9, avgTotalSleep: 45)))
        #expect(display.rows.map(\.high) == ["0밤", "–", "–", "–", "–"])
        #expect(display.rows.map(\.low) == ["3밤", "–", "90%", "45분", "–"])
    }

    @Test func basisText_usesServerPeriodNightCountAndHalfLife() {
        let text = CaffeineSleepReportView.basisText(.fixture(nights: fiveNights))
        #expect(text == "2027-01-11 ~ 2027-01-15 · 수면 기록이 있는 5밤 · 지금 반감기 5.0시간으로 계산")
    }
}
