//
//  CafeNearbyStore.swift
//  captest1
//
//  카페 근처 알림. 사용자가 고른 동(최대 2개)의 카페 구역을 지오펜스로 감시하다가, 들어선 순간 서버가 준 금지 구간 안이면 알림을 띄운다.
//  - 켜고 끄기: 설정 notifications.cafeNearby(서버)를 App 조립층이 `setEnabled`로 전해 준다.
//  - 동 선택·금지 구간·마지막 알림 시각은 기기에만 저장(CafeNearbyLocalStore). 위치·동은 서버로 가지 않는다.
//  - 앱이 꺼져 있다가 위치 이벤트로 깨어나면 AppDelegate가 `start()`만 부른다 — 화면·네트워크 없이 판정까지 끝난다.
//

import Foundation

@MainActor
@Observable
final class CafeNearbyStore {
    /// 선택할 수 있는 동 수.
    nonisolated static let maxDongs = 2
    /// 감시할 카페 구역 수. iOS 앱당 감시 구역은 20개이고 3자리는 예비로 둔다.
    nonisolated static let zoneLimit = 17

    private(set) var isEnabled: Bool
    private(set) var selectedDongCodes: [String]
    /// 지오펜스에 실제로 등록된 구역 수(설정 화면 표시용).
    private(set) var monitoredZoneCount = 0
    /// 카탈로그를 읽은 뒤 채워진다. 읽기 전에는 비어 있다.
    private(set) var allDongs: [CafeDong] = []
    var errorMessage: String?

    var selectedDongs: [CafeDong] {
        selectedDongCodes.compactMap { code in allDongs.first { $0.code == code } }
    }

    private let catalog: any CafeZoneCatalog
    private let monitor: any GeofenceMonitoring
    private let scheduler: any LocalNotificationScheduling
    private let localStore: CafeNearbyLocalStore
    private let now: () -> Date

    init(catalog: any CafeZoneCatalog, monitor: any GeofenceMonitoring,
         scheduler: any LocalNotificationScheduling, localStore: CafeNearbyLocalStore,
         now: @escaping () -> Date = Date.init) {
        self.catalog = catalog
        self.monitor = monitor
        self.scheduler = scheduler
        self.localStore = localStore
        self.now = now
        isEnabled = localStore.isEnabled
        selectedDongCodes = localStore.selectedDongCodes
    }

    // MARK: - 앱 실행

    /// 앱 실행마다 한 번(백그라운드 재실행 포함). 켜져 있으면 같은 이름의 모니터를 다시 만들어 진입 이벤트를 받는다.
    /// 등록된 구역은 시스템이 기억하므로 여기서 다시 등록하지 않는다(카탈로그도 읽지 않는다).
    func start() {
        guard isEnabled else { return }
        startMonitor()
    }

    private func startMonitor() {
        monitor.start { [weak self] zoneID in
            await self?.handleEntry(zoneID: zoneID)
        }
    }

    // MARK: - 설정

    /// 설정 토글(서버 값)이 바뀌었을 때. 켜면 선택한 동의 구역을 등록하고, 끄면 모두 해제한다.
    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        localStore.isEnabled = enabled
        await applyZones()
    }

    /// 선택에 넣거나 뺀다. 이미 2개면 추가하지 않는다.
    func toggle(_ dong: CafeDong) async {
        var codes = selectedDongCodes
        if let index = codes.firstIndex(of: dong.code) {
            codes.remove(at: index)
        } else {
            guard codes.count < Self.maxDongs else { return }
            codes.append(dong.code)
        }
        selectedDongCodes = codes
        localStore.selectedDongCodes = codes
        await applyZones()
    }

    func loadDongsIfNeeded() async {
        guard allDongs.isEmpty else { return }
        do {
            allDongs = try await catalog.dongs()
        } catch {
            errorMessage = "카페 구역 데이터를 읽지 못했어요."
        }
    }

    /// 동 검색. 띄어쓰기를 무시하고 "시도 시군구 동"에서 찾는다("양재2", "서초구양재" 모두 가능).
    func search(_ query: String, limit: Int = 50) -> [CafeDong] {
        let q = query.filter { !$0.isWhitespace }
        guard !q.isEmpty else { return selectedDongs }
        return Array(allDongs.lazy.filter { $0.fullLabel.filter { !$0.isWhitespace }.contains(q) }.prefix(limit))
    }

    /// 감시 구역을 지금 설정에 맞춘다. 꺼져 있거나 동이 없으면 모두 해제.
    private func applyZones() async {
        guard isEnabled, !selectedDongCodes.isEmpty else {
            await monitor.removeAll()
            await refreshMonitoredCount()
            return
        }
        await loadDongsIfNeeded()
        let zones = Self.selectZones(from: selectedDongs, radius: catalog.radius)
        startMonitor()
        await monitor.replaceZones(zones)
        await refreshMonitoredCount()
    }

    func refreshMonitoredCount() async {
        monitoredZoneCount = await monitor.monitoredZoneIDs().count
    }

    /// 고른 동들의 구역을 합쳐 카페 수 내림차순 상위 `limit`개. 같은 수면 먼저 고른 동이 앞선다.
    static func selectZones(from dongs: [CafeDong], radius: Double, limit: Int = zoneLimit) -> [GeoZone] {
        let all = dongs.flatMap(\.zones)
        let sorted = all.enumerated().sorted { a, b in
            a.element.cafeCount != b.element.cafeCount ? a.element.cafeCount > b.element.cafeCount : a.offset < b.offset
        }
        return sorted.prefix(limit).map { zone in
            GeoZone(id: zoneID(zone.element), latitude: zone.element.latitude,
                    longitude: zone.element.longitude, radius: radius)
        }
    }

    /// 좌표로 만든 식별자 — 데이터를 다시 만들어 순서가 바뀌어도 같은 곳이면 같은 구역으로 남는다.
    static func zoneID(_ zone: CafeZone) -> String {
        "cafe_\(Int((zone.latitude * 1_000_000).rounded()))_\(Int((zone.longitude * 1_000_000).rounded()))"
    }

    // MARK: - 금지 구간 · 진입

    /// 알림 계획을 새로 받았을 때(App 조립층이 전달). 빈 목록도 저장한다 — 금지 구간이 사라졌다는 뜻이다.
    func saveWindows(_ windows: [CafeNearbyWindowDTO]) {
        localStore.windows = windows
    }

    /// 구역에 들어선 순간. 네트워크를 쓰지 않는다.
    func handleEntry(zoneID: String) async {
        guard isEnabled else { return }
        let at = now()
        let windows = localStore.windows.map(CafeNearbyWindow.init(dto:))
        guard let window = CafeNearbyGate.decide(now: at, windows: windows, lastAlertAt: localStore.lastAlertAt) else {
            return
        }
        localStore.lastAlertAt = at
        await scheduler.postNow(LocalNotification(
            id: "\(window.reason).\(Int(at.timeIntervalSince1970))", fireAt: at,
            title: window.title, body: window.body))
    }

    // MARK: - 로그아웃

    /// 이전 계정의 선택·구간·알림 기록을 지우고 감시를 해제한다. 다음 로그인 계정의 설정이 오면 다시 켜진다.
    func clear() async {
        localStore.reset()
        isEnabled = false
        selectedDongCodes = []
        await monitor.removeAll()
        await refreshMonitoredCount()
    }
}
