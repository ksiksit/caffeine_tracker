//
//  IntakeHistoryStoreTests.swift
//  captest1Tests
//
//  주간 섭취 히스토리: 요청 기간(섭취일 기준 오늘까지 7일), 서버 값 그대로 보관, 로딩·실패·기록 없음 구분, 실패 뒤 이전 값 유지,
//  로그아웃(reset) 뒤에 도착한 이전 요청의 응답 무시.
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

    // MARK: - 로그아웃과 떠 있는 요청

    private func day15(total: Double) -> IntakeStatsResponse {
        .fixture(days: [.fixture(date: "2027-01-15", total: total, count: 1)])
    }

    @Test func reset_whileRequestInFlight_dropsLateSuccess_andNextRefreshFetchesAgain() async {
        let repo = FakeIntakeStatsRepository()
        repo.holdsResponses = true
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        let previous = Task { await store.refresh() }
        #expect(await repo.waitForPending(1))

        store.reset()
        // 로그아웃 뒤에 이전 계정의 응답이 도착한다
        repo.release(.success(day15(total: 150)))
        await previous.value

        #expect(store.stats == nil)
        #expect(store.loadedAt == nil)
        #expect(store.errorMessage == nil)
        #expect(store.isStale == false)
        #expect(store.isLoading == false)
        #expect(store.daysNewestFirst.isEmpty)

        // 다음 계정의 조회는 실제로 다시 나가고 그 값만 보인다
        let next = Task { await store.refresh() }
        #expect(await repo.waitForPending(1))
        #expect(repo.requests.count == 2)
        repo.release(.success(day15(total: 225)))
        await next.value
        #expect(store.stats?.days.first?.totalMg == 225)
        #expect(store.isLoading == false)
    }

    @Test func reset_whileRequestInFlight_dropsLateFailure() async {
        let repo = FakeIntakeStatsRepository()
        repo.holdsResponses = true
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        let previous = Task { await store.refresh() }
        #expect(await repo.waitForPending(1))

        store.reset()
        repo.release(.failure(FakeError()))
        await previous.value

        #expect(store.errorMessage == nil)
        #expect(store.stats == nil)
        guard case .loading = store.phase else {
            Issue.record("이전 계정의 실패가 반영됨")
            return
        }
    }

    @Test func reset_whileRequestInFlight_previousLoopDoesNotDisturbNextLoop() async {
        let repo = FakeIntakeStatsRepository()
        repo.holdsResponses = true
        let store = IntakeHistoryStore(repository: repo, now: { noon })
        let previous = Task { await store.refresh() }
        #expect(await repo.waitForPending(1))

        store.reset()
        // 이전 요청이 아직 떠 있는 동안 다음 계정의 조회가 시작된다
        let next = Task { await store.refresh() }
        #expect(await repo.waitForPending(2))

        // 이전 루프가 끝나도 다음 계정의 조회 중 상태는 그대로다
        repo.release(.success(day15(total: 150)))
        await previous.value
        #expect(store.stats == nil)
        guard store.isLoading else {
            // 여기서 더 가면 아래 refresh()가 루프를 하나 더 만들어 응답을 기다리며 멈춘다 — 남은 요청을 풀고 끝낸다
            Issue.record("이전 루프가 다음 계정의 조회 중 상태를 꺼 버림")
            repo.release(.failure(FakeError()))
            await next.value
            return
        }

        // 조회 중에 온 요청은 새 루프를 하나 더 만들지 않고, 끝난 뒤 한 번 더 받게 한다
        await store.refresh()
        #expect(repo.requests.count == 2)
        repo.release(.success(day15(total: 225)))
        #expect(await repo.waitForPending(1))
        #expect(repo.requests.count == 3)
        #expect(store.isLoading == true)
        repo.release(.success(day15(total: 300)))
        await next.value

        #expect(store.stats?.days.first?.totalMg == 300)
        #expect(store.isLoading == false)
        #expect(repo.requests.count == 3)
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
