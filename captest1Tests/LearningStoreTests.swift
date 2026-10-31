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
}
