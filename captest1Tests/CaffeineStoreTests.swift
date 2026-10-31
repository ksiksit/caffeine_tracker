//
//  CaffeineStoreTests.swift
//  captest1Tests
//
//  서버 today 응답 → 카드 타입 매핑과 쓰기 실패/성공 흐름. 네트워크 대신 FakeCaffeineRepository.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct CaffeineStoreTests {

    @Test func cutoff_safeAnytime() async {
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(cutoff: CutoffDTO(status: "SAFE_ANYTIME", cutoff: nil, existingAtBedtime: nil)))
        let store = CaffeineStore(repository: repo)
        await store.refresh()
        #expect(store.cutoffResult == .safeAnytime)
    }

    @Test func cutoff_withTime() async {
        let at = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(cutoff: CutoffDTO(status: "CUTOFF", cutoff: at, existingAtBedtime: nil)))
        let store = CaffeineStore(repository: repo)
        await store.refresh()
        #expect(store.cutoffResult == .cutoff(at))
    }

    @Test func cutoff_alreadyExceeded() async {
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(cutoff: CutoffDTO(status: "ALREADY_EXCEEDED", cutoff: nil, existingAtBedtime: 80)))
        let store = CaffeineStore(repository: repo)
        await store.refresh()
        #expect(store.cutoffResult == .alreadyExceeded(80))
    }

    @Test func cutoff_beforeFirstLoad_isSafe() {
        let store = CaffeineStore(repository: FakeCaffeineRepository())
        #expect(store.cutoffResult == .safeAnytime)
        #expect(store.bedtime == nil)
    }

    @Test func refresh_exposesServerBedtimeAndRecords() async {
        let now = Date()
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(now: now, records: [.fixture(amount: 150), .fixture(id: 2, amount: 75)]))
        let store = CaffeineStore(repository: repo)
        await store.refresh()
        #expect(store.bedtime == now.addingTimeInterval(6 * 3600))
        #expect(store.todayTotal == 225)
        #expect(store.chartDoses.map(\.amountMg) == [150, 75])
        #expect(store.errorMessage == nil)
    }

    @Test func residualDoses_includeCarryover_andResetClears() async {
        let repo = FakeCaffeineRepository()
        var today = CaffeineTodayResponse.fixture(records: [.fixture(id: 2, amount: 75)])
        today.carryoverRecords = [.fixture(id: 1, amount: 200)]
        repo.todayResult = .success(today)
        let store = CaffeineStore(repository: repo)
        await store.refresh()

        #expect(store.todayTotal == 75)
        #expect(store.chartDoses.map(\.amountMg) == [75])
        #expect(store.residualDoses.map(\.amountMg) == [200, 75])

        store.reset()
        #expect(store.today == nil)
        #expect(store.residualDoses.isEmpty)
    }

    @Test func refresh_failure_setsErrorMessage() async {
        let repo = FakeCaffeineRepository()
        repo.todayResult = .failure(FakeError())
        let store = CaffeineStore(repository: repo)
        await store.refresh()
        #expect(store.errorMessage != nil)
        #expect(store.today == nil)
    }

    @Test func add_failure_setsErrorAndReturnsFalse() async {
        let repo = FakeCaffeineRepository()
        repo.createResult = .failure(FakeError())
        let store = CaffeineStore(repository: repo)
        let ok = await store.add(amount: 100, drinkName: "커피", timestamp: Date())
        #expect(ok == false)
        #expect(store.errorMessage != nil)
        #expect(repo.calls == ["create"])
    }

    @Test func add_success_refetchesToday() async {
        let repo = FakeCaffeineRepository()
        let store = CaffeineStore(repository: repo)
        let ok = await store.add(amount: 100, drinkName: "커피", timestamp: Date())
        #expect(ok == true)
        #expect(repo.calls == ["create", "today"])
        #expect(store.today != nil)
    }

    @Test func delete_success_refetchesToday() async {
        let repo = FakeCaffeineRepository()
        let store = CaffeineStore(repository: repo)
        let ok = await store.delete(id: 7)
        #expect(ok == true)
        #expect(repo.calls == ["delete", "today"])
    }
}
