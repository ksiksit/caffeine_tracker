//
//  NotificationStoreTests.swift
//  captest1Tests
//
//  서버 알림 계획 → 로컬 예약 교체 흐름. 네트워크·시스템 알림 대신 페이크.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct NotificationStoreTests {

    // 기본 인자는 격리 밖에서 평가돼 MainActor 이니셜라이저를 부를 수 없다 — nil로 받고 본문에서 만든다.
    private func makeStore(
        repo: FakeNotificationRepository? = nil,
        scheduler: FakeLocalNotificationScheduler? = nil
    ) -> NotificationStore {
        NotificationStore(repository: repo ?? FakeNotificationRepository(),
                          scheduler: scheduler ?? FakeLocalNotificationScheduler())
    }

    @Test func refresh_authorized_replacesScheduleWithPlanItems() async {
        let fireAt = Date(timeIntervalSince1970: 1_800_000_000)
        let repo = FakeNotificationRepository()
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: [
            .fixture(type: "CUTOFF", fireAt: fireAt, title: "섭취 마감 30분 전", body: "b"),
        ]))
        let scheduler = FakeLocalNotificationScheduler()
        let store = makeStore(repo: repo, scheduler: scheduler)

        await store.refresh()

        #expect(scheduler.pending == [LocalNotification(id: "CUTOFF.1800000000", fireAt: fireAt,
                                                         title: "섭취 마감 30분 전", body: "b")])
        #expect(store.scheduled == scheduler.pending)
        #expect(store.errorMessage == nil)
    }

    @Test func refresh_emptyPlan_clearsPreviousSchedule() async {
        let repo = FakeNotificationRepository()
        let scheduler = FakeLocalNotificationScheduler()
        let store = makeStore(repo: repo, scheduler: scheduler)
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: [.fixture()]))
        await store.refresh()

        // 기록을 추가해 마감 알림 조건이 사라지면 서버는 빈 목록을 준다 → 예약도 비어야 한다.
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: []))
        await store.refresh()

        #expect(scheduler.pending.isEmpty)
        #expect(scheduler.replaceCount == 2)
    }

    @Test func refresh_failure_keepsExistingSchedule() async {
        let repo = FakeNotificationRepository()
        let scheduler = FakeLocalNotificationScheduler()
        let store = makeStore(repo: repo, scheduler: scheduler)
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: [.fixture()]))
        await store.refresh()

        repo.planResult = .failure(FakeError())
        await store.refresh()

        #expect(scheduler.pending.count == 1)   // 낡은 계획이라도 유지
        #expect(scheduler.replaceCount == 1)
        #expect(store.errorMessage != nil)
    }

    @Test func refresh_withoutPermission_doesNotFetchOrSchedule() async {
        let repo = FakeNotificationRepository()
        let scheduler = FakeLocalNotificationScheduler()
        scheduler.currentPermission = .denied
        let store = makeStore(repo: repo, scheduler: scheduler)

        await store.refresh()

        #expect(repo.planCalls == 0)
        #expect(scheduler.replaceCount == 0)
        #expect(store.permission == .denied)
    }

    @Test func requestPermissionIfNeeded_asksOnlyWhenUndetermined() async {
        let scheduler = FakeLocalNotificationScheduler()
        scheduler.currentPermission = .notDetermined
        let store = makeStore(scheduler: scheduler)

        await store.requestPermissionIfNeeded()
        await store.requestPermissionIfNeeded()

        #expect(scheduler.requestCount == 1)
        #expect(store.permission == .authorized)
    }

    @Test func requestPermissionIfNeeded_deniedBefore_doesNotAskAgain() async {
        let scheduler = FakeLocalNotificationScheduler()
        scheduler.currentPermission = .denied
        let store = makeStore(scheduler: scheduler)

        await store.requestPermissionIfNeeded()

        #expect(scheduler.requestCount == 0)
    }

    @Test func scheduleRefresh_mergesBurstIntoOneFetch() async throws {
        let repo = FakeNotificationRepository()
        let store = makeStore(repo: repo)

        store.scheduleRefresh()
        store.scheduleRefresh()
        store.scheduleRefresh()
        try await Task.sleep(for: .milliseconds(900))

        #expect(repo.planCalls == 1)
    }

    @Test func refresh_success_exposesCafeNearbyWindowsAndBumpsRevision() async {
        let window = CafeNearbyWindowDTO(reason: "CUTOFF_PASSED", activeFrom: Date(), activeUntil: Date().addingTimeInterval(3600),
                                         title: "카페 근처예요", body: "b")
        let repo = FakeNotificationRepository()
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: [], cafeNearbyWindows: [window]))
        let store = makeStore(repo: repo)

        await store.refresh()

        #expect(store.cafeNearbyWindows == [window])
        #expect(store.planRevision == 1)
    }

    @Test func refresh_emptyWindows_stillBumpsRevision() async {
        // 금지 구간이 사라진 것도 조립층이 저장해야 하므로, 빈 목록이 두 번 와도 신호는 오른다.
        let repo = FakeNotificationRepository()
        let store = makeStore(repo: repo)
        await store.refresh()
        await store.refresh()
        #expect(store.cafeNearbyWindows.isEmpty)
        #expect(store.planRevision == 2)
    }

    @Test func refresh_failure_keepsCafeNearbyWindows() async {
        let window = CafeNearbyWindowDTO(reason: "ALREADY_EXCEEDED", activeFrom: Date(), activeUntil: Date().addingTimeInterval(3600),
                                         title: "카페 근처예요", body: "b")
        let repo = FakeNotificationRepository()
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: [], cafeNearbyWindows: [window]))
        let store = makeStore(repo: repo)
        await store.refresh()

        repo.planResult = .failure(FakeError())
        await store.refresh()

        #expect(store.cafeNearbyWindows == [window])
        #expect(store.planRevision == 1)
    }

    @Test func clear_removesScheduledNotifications() async {
        let repo = FakeNotificationRepository()
        repo.planResult = .success(NotificationPlanResponse(now: Date(), items: [.fixture()]))
        let scheduler = FakeLocalNotificationScheduler()
        let store = makeStore(repo: repo, scheduler: scheduler)
        await store.refresh()

        await store.clear()

        #expect(scheduler.pending.isEmpty)
        #expect(store.scheduled.isEmpty)
    }
}
