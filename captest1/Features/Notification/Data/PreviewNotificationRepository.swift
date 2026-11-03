//
//  PreviewNotificationRepository.swift
//  captest1
//
//  #Preview 전용 페이크. 네트워크·시스템 알림·위치 없이 화면만 그린다.
//

import Foundation

nonisolated struct PreviewNotificationRepository: NotificationRepository {
    func plan(now: Date, timeZone: TimeZone) async throws -> NotificationPlanResponse {
        NotificationPlanResponse(now: now, items: [
            NotificationItemDTO(type: "CUTOFF", fireAt: now.addingTimeInterval(3600),
                                title: "섭취 마감 30분 전",
                                body: "23:00 취침 기준, 75mg를 마실 수 있는 마지막 시각은 15:34이에요."),
        ])
    }
}

final class PreviewLocalNotificationScheduler: LocalNotificationScheduling {
    var current: LocalNotificationPermission = .authorized
    func permission() async -> LocalNotificationPermission { current }
    func requestPermission() async -> Bool { current == .authorized }
    func replaceAll(with notifications: [LocalNotification]) async {}
    func removeAll() async {}
    func postNow(_ notification: LocalNotification) async {}
}

/// 동 두 개만 든 작은 카탈로그.
nonisolated struct PreviewCafeZoneCatalog: CafeZoneCatalog {
    let radius: Double = 150
    func dongs() async throws -> [CafeDong] {
        [
            CafeDong(code: "11650652", sido: "서울특별시", sigungu: "서초구", name: "양재2동", zones: [
                CafeZone(latitude: 37.476024, longitude: 127.04417, cafeCount: 23),
                CafeZone(latitude: 37.468843, longitude: 127.042515, cafeCount: 15),
            ]),
            CafeDong(code: "11650651", sido: "서울특별시", sigungu: "서초구", name: "양재1동", zones: [
                CafeZone(latitude: 37.4845, longitude: 127.0345, cafeCount: 12),
            ]),
        ]
    }
}

final class PreviewGeofenceMonitor: GeofenceMonitoring {
    private var zones: [GeoZone] = []
    func start(onEnter: @escaping @MainActor (String) async -> Void) {}
    func replaceZones(_ zones: [GeoZone]) async { self.zones = zones }
    func removeAll() async { zones = [] }
    func monitoredZoneIDs() async -> [String] { zones.map(\.id) }
}
