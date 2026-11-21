//
//  IntakeHistoryStoreTests.swift
//  captest1Tests
//
//  주간 섭취 히스토리: 요청 기간(섭취일 기준 오늘까지 7일), 서버 값 그대로 보관, 로딩·실패·기록 없음 구분, 실패 뒤 이전 값 유지.
//  네트워크 대신 FakeIntakeStatsRepository.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct IntakeHistoryStoreTests {
    /// 기기 타임존의 2027-01-15 정오
    private let noon = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))!

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: day, hour: hour, minute: minute))!
    }

    // MARK: - 요청 기간

    @Test func refresh_requestsSevenDaysEndingToday() async {
        let repo = FakeIntakeStatsRepository()
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        await store.refresh()
        #expect(repo.requests.count == 1)
        #expect(repo.requests.first?.from == "2027-01-09")
        #expect(repo.requests.first?.to == "2027-01-15")
    }

    @Test func range_beforeFiveAM_endsOnPreviousCalendarDay() {
        // 섭취일은 새벽 5시에 바뀐다 — 04:59는 아직 전날, 05:00부터 그날
        #expect(IntakeHistoryStore.range(endingOn: date(day: 15, hour: 4, minute: 59))
                == .init(from: "2027-01-08", to: "2027-01-14"))
        #expect(IntakeHistoryStore.range(endingOn: date(day: 15, hour: 5))
                == .init(from: "2027-01-09", to: "2027-01-15"))
    }

    // MARK: - 서버 값 그대로

    @Test func loaded_keepsServerValuesAsIs_andListsNewestFirst() async {
        let repo = FakeIntakeStatsRepository()
        // 요약 값이 days에서 계산한 값과 일부러 다르다 — 앱이 다시 계산하지 않는지 본다
        repo.result = .success(.fixture(
            days: [
                .fixture(date: "2027-01-13", total: 420.4, count: 3, overLimit: true),
                .fixture(date: "2027-01-14"),
                .fixture(date: "2027-01-15", total: 150, count: 1),
            ],
            average: 999, max: 888, overLimitDayCount: 5, sentence: "서버 문장"))
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        await store.refresh()

        guard case .loaded(let stats) = store.phase else {
            Issue.record("loaded가 아님")
            return
        }
        #expect(stats.averageDailyMg == 999)
        #expect(stats.maxDailyMg == 888)
        #expect(stats.overLimitDayCount == 5)
        #expect(stats.summarySentence == "서버 문장")
        #expect(store.daysNewestFirst.map(\.date) == ["2027-01-15", "2027-01-14", "2027-01-13"])
        #expect(store.daysNewestFirst.last?.totalMg == 420.4)
        #expect(store.daysNewestFirst.last?.recordCount == 3)
        #expect(store.daysNewestFirst.last?.overLimit == true)
    }

    // MARK: - 상태

    @Test func phase_isLoadingBeforeFirstResponse() {
        let store = IntakeHistoryStore(repository: FakeIntakeStatsRepository(), now: { noon })
        guard case .loading = store.phase else {
            Issue.record("loading이 아님")
            return
        }
    }

    @Test func noRecordedDays_isEmpty_withServerSentence() async {
        let repo = FakeIntakeStatsRepository()
        repo.result = .success(.fixture(days: [.fixture(date: "2027-01-14"), .fixture(date: "2027-01-15")],
                                        sentence: "최근 7일 하루 평균을 낼 섭취 기록이 아직 없어요."))
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        await store.refresh()
        guard case .empty(let stats) = store.phase else {
            Issue.record("empty가 아님")
            return
        }
        #expect(stats.summarySentence == "최근 7일 하루 평균을 낼 섭취 기록이 아직 없어요.")
    }

    @Test func failure_withoutPrevious_isFailed_notEmpty() async {
        let repo = FakeIntakeStatsRepository()
        repo.result = .failure(FakeError())
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        await store.refresh()
        guard case .failed = store.phase else {
            Issue.record("failed가 아님")
            return
        }
        #expect(store.stats == nil)
        #expect(store.isStale == false)
        #expect(store.daysNewestFirst.isEmpty)
    }

    @Test func failure_afterSuccess_keepsStatsAsStale_thenRecovers() async {
        let repo = FakeIntakeStatsRepository()
        repo.result = .success(.fixture(days: [.fixture(date: "2027-01-15", total: 150, count: 1)]))
        var now = noon
        let store = IntakeHistoryStore(repository: repo, now: { now })
        await store.refresh()
        #expect(store.isStale == false)
        #expect(store.loadedAt == noon)

        now = noon.addingTimeInterval(10 * 60)
        repo.result = .failure(FakeError())
        await store.refresh()
        #expect(store.stats?.days.first?.totalMg == 150)
        #expect(store.isStale == true)
        #expect(store.loadedAt == noon)
        #expect(store.errorMessage != nil)

        repo.result = .success(.fixture(days: [.fixture(date: "2027-01-15", total: 225, count: 2)]))
        await store.refresh()
        #expect(store.isStale == false)
        #expect(store.errorMessage == nil)
        #expect(store.stats?.days.first?.totalMg == 225)
    }

    @Test func failure_afterDayChange_dropsPreviousPeriod() async {
        let repo = FakeIntakeStatsRepository()
        repo.result = .success(.fixture(days: [.fixture(date: "2027-01-15", total: 150, count: 1)]))
        var now = noon
        let store = IntakeHistoryStore(repository: repo, now: { now })
        await store.refresh()

        now = noon.addingTimeInterval(86_400)
        repo.result = .failure(FakeError())
        await store.refresh()
        #expect(store.stats == nil)
        #expect(store.isStale == false)
        #expect(store.loadedAt == nil)
        guard case .failed = store.phase else {
            Issue.record("failed가 아님")
            return
        }
    }

    @Test func refresh_fetchesEveryTime() async {
        // 홈에서 기록을 고치고 다시 들어오면 새 값을 받아야 한다
        let repo = FakeIntakeStatsRepository()
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        await store.refresh()
        await store.refresh()
        #expect(repo.requests.count == 2)
    }

    @Test func reset_clearsEverything() async {
        let repo = FakeIntakeStatsRepository()
        repo.result = .success(.fixture(days: [.fixture(date: "2027-01-15", total: 150, count: 1)]))
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        await store.refresh()
        store.reset()
        #expect(store.stats == nil)
        #expect(store.errorMessage == nil)
        #expect(store.isStale == false)
        #expect(store.loadedAt == nil)
    }

    // MARK: - 날짜별 행 문구

    @Test func detailText_showsCountAndLastIntake_orNoRecord() {
        #expect(IntakeHistoryView.detailText(.fixture(date: "2027-01-14")) == "기록 없음")
        #expect(IntakeHistoryView.detailText(.fixture(date: "2027-01-15", total: 300, count: 2,
                                                      last: date(day: 15, hour: 16, minute: 40)))
                == "2회 · 마지막 오후 4:40")
        #expect(IntakeHistoryView.detailText(.fixture(date: "2027-01-15", total: 75, count: 1)) == "1회")
    }
}
