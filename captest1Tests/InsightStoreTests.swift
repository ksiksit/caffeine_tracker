//
//  InsightStoreTests.swift
//  captest1Tests
//
//  수면 탭 밤별 카페인: 요청 기간(최근 7밤), 서버 nights를 날짜로 찾기·빠진 밤, 실패·재조회 규칙. 네트워크 대신 FakeInsightRepository.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct InsightStoreTests {
    /// 기기 타임존의 2027-01-15 정오(1시간 안팎을 더해도 날짜가 바뀌지 않는 시각)
    private let noon = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))!

    @Test func refresh_requestsLastSevenMorningDates() async {
        let repo = FakeInsightRepository()
        let store = InsightStore(repository: repo, now: { noon })
        await store.refresh()
        #expect(repo.requests.count == 1)
        #expect(repo.requests.first?.from == "2027-01-09")
        #expect(repo.requests.first?.to == "2027-01-15")
        #expect(store.nightKeys.count == 7)
    }

    @Test func recentNights_keepsMissingDatesAsNil_andServerValuesAsIs() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(nights: [
            .fixture(date: "2027-01-12", residual: 74.81, dayTotal: 300, sol: 32.5),
            .fixture(date: "2027-01-15", residual: 0, dayTotal: 0, sol: nil),
        ]))
        let store = InsightStore(repository: repo, now: { noon })
        await store.refresh()

        let rows = store.recentNights
        #expect(rows.map(\.key) == ["2027-01-09", "2027-01-10", "2027-01-11", "2027-01-12", "2027-01-13", "2027-01-14", "2027-01-15"])
        #expect(rows.filter { $0.night == nil }.count == 5)
        let jan12 = rows.first { $0.key == "2027-01-12" }?.night
        #expect(jan12?.residualAtBedtimeMg == 74.81)
        #expect(jan12?.dayTotalMg == 300)
        #expect(jan12?.solMinutes == 32.5)
    }

    @Test func nightEndingOn_matchesLastNightCardDate() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(nights: [.fixture(date: "2027-01-15", residual: 51.2)]))
        let store = InsightStore(repository: repo, now: { noon })
        await store.refresh()
        #expect(store.night(endingOn: noon)?.residualAtBedtimeMg == 51.2)
        // 지난밤이 리포트에서 빠졌으면(취침 시각 없음) 다른 밤으로 대신하지 않는다
        #expect(store.night(endingOn: noon.addingTimeInterval(-86_400)) == nil)
    }

    @Test func threshold_comesFromServer() async {
        let repo = FakeInsightRepository()
        repo.result = .success(.fixture(threshold: 60))
        let store = InsightStore(repository: repo, now: { noon })
        #expect(store.residualThresholdMg == nil)
        await store.refresh()
        #expect(store.residualThresholdMg == 60)
    }

    @Test func failure_clearsReport_andSetsError_notEmpty() async {
        let repo = FakeInsightRepository()
        let store = InsightStore(repository: repo, now: { noon })
        await store.refresh()
        #expect(store.report != nil)

        repo.result = .failure(FakeError())
        await store.refresh()
        #expect(store.report == nil)
        #expect(store.recentNights.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func refreshIfNeeded_skipsWhenFresh_refetchesWhenInvalidatedOrOld() async {
        let repo = FakeInsightRepository()
        var now = noon
        let store = InsightStore(repository: repo, now: { now })
        await store.refreshIfNeeded()
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 1)

        store.invalidate()
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 2)

        now = noon.addingTimeInterval(3601)
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 3)
    }

    @Test func reset_clearsEverything() async {
        let repo = FakeInsightRepository()
        let store = InsightStore(repository: repo, now: { noon })
        await store.refresh()
        store.reset()
        #expect(store.report == nil)
        #expect(store.nightKeys.isEmpty)
        #expect(store.errorMessage == nil)
        await store.refreshIfNeeded()
        #expect(repo.requests.count == 2)
    }

    @Test func residualEmphasis_usesServerBoundaryInclusive() {
        // 서버 비교 A: high = 잔량 ≥ residualThresholdMg
        #expect(InsightFormat.isHigh(50, threshold: 50))
        #expect(!InsightFormat.isHigh(49.99, threshold: 50))
    }
}
