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

    @Test func cutoff_beforeFirstLoad_isNil_notSafe() {
        // 서버 값이 없을 때 "지금 OK"(.safeAnytime)로 보이면 안 된다
        let store = CaffeineStore(repository: FakeCaffeineRepository())
        #expect(store.cutoffResult == nil)
        #expect(store.bedtime == nil)
    }

    @Test func cutoff_unknownStatusOrMissingTime_isNil() async {
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(cutoff: CutoffDTO(status: "SOMETHING_NEW", cutoff: nil, existingAtBedtime: nil)))
        let store = CaffeineStore(repository: repo)
        await store.refresh()
        #expect(store.cutoffResult == nil)

        repo.todayResult = .success(.fixture(cutoff: CutoffDTO(status: "CUTOFF", cutoff: nil, existingAtBedtime: nil)))
        await store.refresh()
        #expect(store.cutoffResult == nil)
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

    // MARK: - 마지막 today 캐시

    /// 2027-01-15 14:00 KST 근처 고정 시각. 하루 경계(05:00) 판정이 기기 타임존에 흔들리지 않게 서울로 고정한다.
    private static let seoul = TimeZone(identifier: "Asia/Seoul")!
    private static func kst(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents(year: 2027, month: 1, day: day, hour: hour, minute: minute)
        c.timeZone = seoul
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    /// 기기 타임존의 정오. 스토어는 Calendar.current로 하루 경계를 보므로, 몇 분 더해도 경계(05:00)를 넘지 않는 시각을 쓴다.
    private static let localNoon = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))!

    private func makeCache() -> CaffeineTodayCache {
        CaffeineTodayCache(defaults: UserDefaults(suiteName: "CaffeineStoreTests.\(UUID().uuidString)")!)
    }

    @Test func refreshSuccess_savesForAccount_andNextLaunchShowsItStale() async {
        let cache = makeCache()
        let fetchedAt = Self.localNoon
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(now: fetchedAt, records: [.fixture(amount: 150)]))
        let first = CaffeineStore(repository: repo, cache: cache)
        first.activate(accountId: 7)
        await first.refresh()
        #expect(first.isStale == false)

        // 다음 실행: 서버에 닿기 전에 같은 계정의 마지막 값을 꺼낸다
        let second = CaffeineStore(repository: FakeCaffeineRepository(), cache: cache, now: { fetchedAt.addingTimeInterval(10 * 60) })
        second.activate(accountId: 7)
        #expect(second.today?.now == fetchedAt)
        #expect(second.todayTotal == 150)
        #expect(second.isStale == true)
    }

    @Test func refreshBeforeActivate_savesOnActivate() async {
        let cache = makeCache()
        let now = Self.localNoon
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(now: now))
        let store = CaffeineStore(repository: repo, cache: cache)
        await store.refresh()
        #expect(cache.load(accountId: 7) == nil)
        store.activate(accountId: 7)
        #expect(cache.load(accountId: 7)?.now == now)
    }

    @Test func cache_otherAccount_isNotShown() async {
        let cache = makeCache()
        let now = Self.localNoon
        cache.save(.fixture(now: now), accountId: 1)
        let store = CaffeineStore(repository: FakeCaffeineRepository(), cache: cache, now: { now })
        store.activate(accountId: 2)
        #expect(store.today == nil)
        #expect(store.cutoffResult == nil)
    }

    @Test func cache_fromPreviousDay_isNotShown() {
        let cache = makeCache()
        // 1/15 23:00에 받은 값은 1/16 05:00(다음 날 경계)부터 쓰지 않는다. 04:59까지는 같은 날
        cache.save(.fixture(now: Self.kst(15, 23)), accountId: 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.seoul
        let cached = cache.load(accountId: 1)!
        #expect(CaffeineTodayCache.isUsable(cached, at: Self.kst(16, 4, 59), calendar: calendar))
        #expect(!CaffeineTodayCache.isUsable(cached, at: Self.kst(16, 5), calendar: calendar))
        // 새벽 4시에 받은 값은 전날(1/14 05:00 시작) 소속
        let early = CaffeineTodayResponse.fixture(now: Self.kst(15, 4))
        #expect(!CaffeineTodayCache.isUsable(early, at: Self.kst(15, 5), calendar: calendar))
    }

    @Test func refreshFailure_keepsPreviousValueAsStale() async {
        let now = Self.localNoon
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(now: now, cutoff: CutoffDTO(status: "SAFE_ANYTIME", cutoff: nil, existingAtBedtime: nil)))
        let store = CaffeineStore(repository: repo, now: { now.addingTimeInterval(5 * 60) })
        await store.refresh()
        repo.todayResult = .failure(FakeError())
        await store.refresh()
        #expect(store.today?.now == now)
        #expect(store.isStale == true)
        #expect(store.errorMessage != nil)

        // 다시 성공하면 최신 값으로 돌아온다
        repo.todayResult = .success(.fixture(now: now.addingTimeInterval(5 * 60)))
        await store.refresh()
        #expect(store.isStale == false)
        #expect(store.errorMessage == nil)
    }

    @Test func refreshFailure_afterDayBoundary_dropsYesterday() async {
        let fetched = Self.localNoon
        let repo = FakeCaffeineRepository()
        repo.todayResult = .success(.fixture(now: fetched))
        let store = CaffeineStore(repository: repo, now: { fetched.addingTimeInterval(26 * 3600) })
        await store.refresh()
        repo.todayResult = .failure(FakeError())
        await store.refresh()
        #expect(store.today == nil)
        #expect(store.isStale == false)
        #expect(store.cutoffResult == nil)
    }

    @Test func reset_clearsCache() async {
        let cache = makeCache()
        let store = CaffeineStore(repository: FakeCaffeineRepository(), cache: cache)
        store.activate(accountId: 3)
        await store.refresh()
        #expect(cache.load(accountId: 3) != nil)
        store.reset()
        #expect(cache.load(accountId: 3) == nil)
        #expect(store.isStale == false)
    }
}
