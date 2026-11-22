//
//  LearningStoreTests.swift
//  captest1Tests
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct LearningStoreTests {

    @Test func learnedRevision_bumpsOnlyWhenUpdated() async {
        let repo = FakeLearningRepository()
        let store = LearningStore(repository: repo)
        await store.refresh()
        #expect(store.learnedRevision == 0)

        repo.runResult = .success(LearningRunResponse(updatedCount: 1, skipReason: nil, skipMessage: nil))
        await store.refresh()
        #expect(store.learnedRevision == 1)

        store.reset()
        #expect(store.dashboard == nil)
        #expect(store.hasLoaded == false)
    }

    @Test func refresh_showsSkipMessage_whenNothingUpdated() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(updatedCount: 0, skipReason: "NO_SLEEP", skipMessage: "수면 기록이 없어요"))
        let store = LearningStore(repository: repo)
        await store.refresh()
        #expect(store.skipMessage == "수면 기록이 없어요")
        #expect(store.dashboard != nil)
        #expect(repo.calls == ["run", "dashboard"])
    }

    @Test func refresh_clearsSkipMessage_whenUpdated() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(updatedCount: 1, skipReason: nil, skipMessage: nil))
        repo.dashboardResult = .success(.fixture(count: 1))
        let store = LearningStore(repository: repo)
        await store.refresh()
        #expect(store.skipMessage == nil)
        #expect(store.dashboard?.count == 1)
    }

    @Test func refresh_runFails_stillLoadsDashboard() async {
        let repo = FakeLearningRepository()
        repo.runResult = .failure(FakeError())
        repo.dashboardResult = .success(.fixture(count: 3))
        let store = LearningStore(repository: repo)
        await store.refresh()
        #expect(store.dashboard?.count == 3)
        #expect(repo.calls == ["run", "dashboard"])
        #expect(store.isLoading == false)
        #expect(store.errorMessage == nil)
    }

    @Test func refresh_networkFailure_skipsDashboardRetry_andSetsError() async {
        let repo = FakeLearningRepository()
        repo.runResult = .failure(APIError.network)
        let store = LearningStore(repository: repo)
        await store.refresh()
        #expect(repo.calls == ["run"])
        #expect(store.dashboard == nil)
        #expect(store.errorMessage != nil)
        #expect(store.hasLoaded)
    }

    @Test func refresh_bothFail_keepsPreviousDashboard() async {
        let repo = FakeLearningRepository()
        repo.dashboardResult = .success(.fixture(count: 2))
        let store = LearningStore(repository: repo)
        await store.refresh()

        repo.runResult = .failure(FakeError())
        repo.dashboardResult = .failure(FakeError())
        await store.refresh()
        #expect(store.dashboard?.count == 2)
        #expect(store.errorMessage != nil)
    }

    @Test func refresh_success_clearsPreviousError() async {
        let repo = FakeLearningRepository()
        repo.runResult = .failure(APIError.network)
        let store = LearningStore(repository: repo)
        await store.refresh()

        repo.runResult = .success(LearningRunResponse(updatedCount: 1, skipReason: nil, skipMessage: nil))
        await store.refresh()
        #expect(store.errorMessage == nil)
        #expect(store.dashboard != nil)
    }

    // MARK: - 어젯밤 학습 여부 (KAN-4)

    /// 오늘 날짜를 고정한다. 관측 날짜는 그 밤이 끝난 아침의 로컬 날짜다.
    private static let today = "2026-06-02"
    private static let fixedNow: () -> Date = { ServerDateCoding.localDate.date(from: today)!.addingTimeInterval(9 * 3600) }

    @Test func lastNight_learned_whenThisRunLearnedLastNight() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(updatedCount: 1, skipReason: nil, skipMessage: nil))
        repo.dashboardResult = .success(.fixture(count: 2, observationDates: ["2026-06-01", Self.today]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .learned)
    }

    /// 같은 날 다시 열면 서버는 ALREADY_LEARNED로 건너뛴다. 어젯밤은 이미 학습된 것이므로 "건너뜀"으로 보이면 안 된다.
    @Test func lastNight_learned_whenAlreadyLearnedToday() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(
            updatedCount: 0, skipReason: "ALREADY_LEARNED", skipMessage: "최근 수면 기록은 이미 학습에 반영됐어요."))
        repo.dashboardResult = .success(.fixture(count: 1, observationDates: [Self.today]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .learned)
    }

    @Test func lastNight_skipped_showsServerReason_evenWithObservations() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(
            updatedCount: 0, skipReason: "SLEEP_TOO_SHORT", skipMessage: "최근 수면 시간이 4시간보다 짧아 학습하지 않았어요."))
        repo.dashboardResult = .success(.fixture(count: 3, observationDates: ["2026-05-30", "2026-05-31", "2026-06-01"]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .skipped(reason: "최근 수면 시간이 4시간보다 짧아 학습하지 않았어요."))
        #expect(store.lastNight?.text == "어젯밤: 건너뜀 · 최근 수면 시간이 4시간보다 짧아 학습하지 않았어요.")
    }

    /// 어젯밤 데이터가 서버에 없고 그 전 밤은 이미 학습된 경우. "건너뜀 · 이미 반영됐어요"로 보이면 안 된다.
    @Test func lastNight_noSleepRecord_whenAlreadyLearnedButNotObservedToday() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(
            updatedCount: 0, skipReason: "ALREADY_LEARNED", skipMessage: "최근 수면 기록은 이미 학습에 반영됐어요."))
        repo.dashboardResult = .success(.fixture(count: 2, observationDates: ["2026-05-31", "2026-06-01"]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .noSleepRecord)
        #expect(store.lastNight?.text == "어젯밤: 아직 수면 기록 없음")
    }

    /// 더 오래된 밤만 학습된 실행은 서버가 사유를 주지 않는다. 어젯밤 관측이 없으니 사유 없는 건너뜀이다.
    @Test func lastNight_skippedWithoutReason_whenOnlyOlderNightLearned() async {
        let repo = FakeLearningRepository()
        repo.runResult = .success(LearningRunResponse(updatedCount: 1, skipReason: nil, skipMessage: nil))
        repo.dashboardResult = .success(.fixture(count: 1, observationDates: ["2026-06-01"]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .skipped(reason: nil))
        #expect(store.lastNight?.text == "어젯밤: 건너뜀")
    }

    /// 학습 실행이 실패하면 건너뛰었다고 단정하지 않는다. 오늘 관측이 있으면 학습됨만 알 수 있다.
    @Test func lastNight_runFails_unknownUnlessObservedToday() async {
        let repo = FakeLearningRepository()
        repo.runResult = .failure(FakeError())
        repo.dashboardResult = .success(.fixture(count: 1, observationDates: ["2026-06-01"]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == nil)

        repo.dashboardResult = .success(.fixture(count: 2, observationDates: ["2026-06-01", Self.today]))
        await store.refresh()
        #expect(store.lastNight == .learned)
    }

    /// 학습 실행은 됐고 대시보드 첫 조회만 실패한 경우, 재시도에서 실행 결과(사유)를 잃지 않는다.
    @Test func lastNight_keepsRunReason_whenDashboardRetrySucceeds() async {
        let repo = FlakyDashboardRepository(
            run: LearningRunResponse(updatedCount: 0, skipReason: "INVALID_SOL", skipMessage: "수면 잠복기 값이 유효 범위를 벗어났어요."),
            dashboard: .fixture(count: 1, observationDates: ["2026-06-01"]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .skipped(reason: "수면 잠복기 값이 유효 범위를 벗어났어요."))
        #expect(store.errorMessage == nil)
    }

    @Test func lastNight_clearedOnReset() async {
        let repo = FakeLearningRepository()
        repo.dashboardResult = .success(.fixture(count: 1, observationDates: [Self.today]))
        let store = LearningStore(repository: repo, now: Self.fixedNow)
        await store.refresh()
        #expect(store.lastNight == .learned)
        store.reset()
        #expect(store.lastNight == nil)
    }
}

/// 대시보드 첫 조회만 실패하는 저장소.
private final class FlakyDashboardRepository: LearningRepository, @unchecked Sendable {
    private let runResponse: LearningRunResponse
    private let dashboardResponse: LearningDashboardResponse
    @Locked private var dashboardCalls = 0

    init(run: LearningRunResponse, dashboard: LearningDashboardResponse) {
        runResponse = run
        dashboardResponse = dashboard
    }

    func run(timeZone: TimeZone) async throws -> LearningRunResponse { runResponse }

    func dashboard() async throws -> LearningDashboardResponse {
        $dashboardCalls.mutate { $0 += 1 }
        if dashboardCalls == 1 { throw FakeError() }
        return dashboardResponse
    }
}
