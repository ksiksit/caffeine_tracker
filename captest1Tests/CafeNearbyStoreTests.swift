//
//  CafeNearbyStoreTests.swift
//  captest1Tests
//
//  동 선택 → 감시 구역 교체, 진입 → 판정 → 즉시 알림, 끄기·로그아웃 정리. 위치·알림 센터 대신 페이크.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct CafeNearbyStoreTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let yangjae2 = CafeDong.fixture(code: "11650652", name: "양재2동",
                                            counts: [23, 15, 10, 6, 6, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 2])
    private let yangjae1 = CafeDong.fixture(code: "11650651", name: "양재1동", counts: [30, 12, 1])
    private let small = CafeDong.fixture(code: "11110001", name: "작은동", sigungu: "종로구", counts: [3, 2])

    private struct Harness {
        let store: CafeNearbyStore
        let monitor: FakeGeofenceMonitor
        let scheduler: FakeLocalNotificationScheduler
        let localStore: CafeNearbyLocalStore
    }

    private func make(dongs: [CafeDong]? = nil, defaults: UserDefaults? = nil, now: Date? = nil,
                      clock: (() -> Date)? = nil) -> Harness {
        let defaults = defaults ?? UserDefaults(suiteName: "CafeNearbyStoreTests.\(UUID().uuidString)")!
        let monitor = FakeGeofenceMonitor()
        let scheduler = FakeLocalNotificationScheduler()
        let localStore = CafeNearbyLocalStore(defaults: defaults)
        let fixed = now ?? t0
        let store = CafeNearbyStore(catalog: FakeCafeZoneCatalog(dongs ?? [yangjae2, yangjae1, small]),
                                    monitor: monitor, scheduler: scheduler, localStore: localStore,
                                    now: clock ?? { fixed })
        return Harness(store: store, monitor: monitor, scheduler: scheduler, localStore: localStore)
    }

    private func window(from: TimeInterval, until: TimeInterval) -> CafeNearbyWindowDTO {
        CafeNearbyWindowDTO(reason: "CUTOFF_PASSED", activeFrom: t0.addingTimeInterval(from),
                            activeUntil: t0.addingTimeInterval(until), title: "카페 근처예요", body: "마감이 지났어요")
    }

    // MARK: - 구역 선택

    @Test func selectZones_twoDongs_mergesTop17ByCafeCount() {
        let zones = CafeNearbyStore.selectZones(from: [yangjae2, yangjae1], radius: 150)
        #expect(zones.count == 17)
        // 양재1동의 30곳 구역이 맨 앞, 1곳 구역은 잘린다.
        #expect(zones.first?.id == CafeNearbyStore.zoneID(yangjae1.zones[0]))
        #expect(zones.contains { $0.id == CafeNearbyStore.zoneID(yangjae1.zones[1]) })
        #expect(!zones.contains { $0.id == CafeNearbyStore.zoneID(yangjae1.zones[2]) })
        #expect(zones.allSatisfy { $0.radius == 150 })
    }

    @Test func selectZones_oneSmallDong_takesAll() {
        let zones = CafeNearbyStore.selectZones(from: [small], radius: 150)
        #expect(zones.map(\.id) == small.zones.map(CafeNearbyStore.zoneID))
    }

    @Test func selectZones_noDongs_isEmpty() {
        #expect(CafeNearbyStore.selectZones(from: [], radius: 150).isEmpty)
    }

    // MARK: - 켜기·동 선택

    @Test func enableWithDong_registersZonesAndStartsMonitor() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)

        #expect(h.monitor.zones.count == 17)
        #expect(h.store.monitoredZoneCount == 17)
        #expect(h.monitor.startCount >= 1)
        #expect(h.localStore.selectedDongCodes == ["11650652"])
    }

    @Test func secondDong_keeps17Zones() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        await h.store.toggle(yangjae1)

        #expect(h.store.selectedDongCodes == ["11650652", "11650651"])
        #expect(h.store.monitoredZoneCount == 17)
    }

    @Test func thirdDong_isNotAdded() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        await h.store.toggle(yangjae1)
        await h.store.toggle(small)

        #expect(h.store.selectedDongCodes.count == 2)
        #expect(!h.store.selectedDongCodes.contains(small.code))
    }

    @Test func removingLastDong_unregistersAllZones() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(small)
        await h.store.toggle(small)

        #expect(h.monitor.zones.isEmpty)
        #expect(h.store.monitoredZoneCount == 0)
    }

    @Test func disable_unregistersAllZones() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)

        await h.store.setEnabled(false)

        #expect(h.monitor.zones.isEmpty)
        #expect(h.store.monitoredZoneCount == 0)
        #expect(h.localStore.isEnabled == false)
        #expect(h.store.selectedDongCodes == ["11650652"])   // 다시 켜면 같은 동으로
    }

    @Test func dongSelectedWhileDisabled_doesNotRegister() async {
        let h = make()
        await h.store.toggle(yangjae2)
        #expect(h.monitor.zones.isEmpty)
    }

    @Test func search_ignoresSpacesAndMatchesDistrict() async {
        let h = make()
        await h.store.loadDongsIfNeeded()
        #expect(h.store.search("양재2").map(\.code) == ["11650652"])
        #expect(Set(h.store.search("서초구 양재").map(\.code)) == ["11650652", "11650651"])
        #expect(h.store.search("없는동").isEmpty)
    }

    @Test func catalogFailure_setsError() async {
        let monitor = FakeGeofenceMonitor()
        let store = CafeNearbyStore(catalog: FakeCafeZoneCatalog(failure: FakeError()), monitor: monitor,
                                    scheduler: FakeLocalNotificationScheduler(),
                                    localStore: CafeNearbyLocalStore(defaults: UserDefaults(suiteName: UUID().uuidString)!))
        await store.loadDongsIfNeeded()
        #expect(store.errorMessage != nil)
    }

    // MARK: - 진입

    @Test func entryInsideWindow_postsServerTextOnce() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        h.store.saveWindows([window(from: -3600, until: 3600)])

        await h.monitor.simulateEntry(h.monitor.zones[0].id)

        #expect(h.scheduler.posted.count == 1)
        #expect(h.scheduler.posted.first?.title == "카페 근처예요")
        #expect(h.scheduler.posted.first?.body == "마감이 지났어요")
        #expect(h.localStore.lastAlertAt == t0)
    }

    @Test func entryOutsideWindow_doesNotPost() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        h.store.saveWindows([window(from: 60, until: 3600)])

        await h.monitor.simulateEntry(h.monitor.zones[0].id)

        #expect(h.scheduler.posted.isEmpty)
    }

    @Test func secondEntryWithin60Minutes_evenOtherZone_isSuppressed() async {
        var current = t0
        let h = make(clock: { current })
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        h.store.saveWindows([window(from: -3600, until: 4 * 3600)])

        await h.monitor.simulateEntry(h.monitor.zones[0].id)
        current = t0.addingTimeInterval(30 * 60)
        await h.monitor.simulateEntry(h.monitor.zones[1].id)
        #expect(h.scheduler.posted.count == 1)

        current = t0.addingTimeInterval(61 * 60)
        await h.monitor.simulateEntry(h.monitor.zones[2].id)
        #expect(h.scheduler.posted.count == 2)
    }

    @Test func entryWhileDisabled_doesNotPost() async {
        let h = make()
        h.store.saveWindows([window(from: -3600, until: 3600)])
        await h.store.handleEntry(zoneID: "cafe_1_1")
        #expect(h.scheduler.posted.isEmpty)
    }

    @Test func emptyWindowsReplaceOldOnes() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        h.store.saveWindows([window(from: -3600, until: 3600)])
        h.store.saveWindows([])   // 금지 구간이 사라짐(예: 설정 변경)

        await h.monitor.simulateEntry(h.monitor.zones[0].id)

        #expect(h.scheduler.posted.isEmpty)
    }

    // MARK: - 백그라운드 재실행

    @Test func relaunch_startsMonitorFromDeviceStateWithoutCatalog() async {
        let defaults = UserDefaults(suiteName: "CafeNearbyStoreTests.\(UUID().uuidString)")!
        let first = make(defaults: defaults)
        await first.store.setEnabled(true)
        await first.store.toggle(yangjae2)
        first.store.saveWindows([window(from: -3600, until: 3600)])

        // 위치 이벤트로 새 프로세스가 뜬 상황: 같은 기기 저장소로 스토어를 새로 만들고 start만 부른다.
        let relaunched = make(dongs: [], defaults: defaults)
        relaunched.store.start()
        await relaunched.monitor.simulateEntry(CafeNearbyStore.zoneID(yangjae2.zones[0]))

        #expect(relaunched.store.isEnabled)
        #expect(relaunched.monitor.startCount == 1)
        #expect(relaunched.scheduler.posted.count == 1)
    }

    @Test func relaunch_whenDisabled_doesNotStartMonitor() {
        let h = make()
        h.store.start()
        #expect(h.monitor.startCount == 0)
    }

    // MARK: - 로그아웃

    @Test func clear_unregistersZonesAndForgetsDeviceState() async {
        let h = make()
        await h.store.setEnabled(true)
        await h.store.toggle(yangjae2)
        h.store.saveWindows([window(from: -3600, until: 3600)])
        await h.monitor.simulateEntry(h.monitor.zones[0].id)

        await h.store.clear()

        #expect(h.monitor.zones.isEmpty)
        #expect(h.store.monitoredZoneCount == 0)
        #expect(h.store.isEnabled == false)
        #expect(h.store.selectedDongCodes.isEmpty)
        #expect(h.localStore.windows.isEmpty)
        #expect(h.localStore.lastAlertAt == nil)
        #expect(h.localStore.isEnabled == false)
    }
}
