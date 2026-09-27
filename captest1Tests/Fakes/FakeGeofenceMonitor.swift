//
//  FakeGeofenceMonitor.swift
//  captest1Tests
//
//  CoreLocation 대신 등록된 구역만 기록한다. 진입은 `simulateEntry`로 흉내 낸다.
//

import Foundation
@testable import captest1

@MainActor
final class FakeGeofenceMonitor: GeofenceMonitoring {
    private(set) var zones: [GeoZone] = []
    private(set) var startCount = 0
    private(set) var replaceCount = 0
    private var onEnter: (@MainActor (String) async -> Void)?

    func start(onEnter: @escaping @MainActor (String) async -> Void) {
        startCount += 1
        if self.onEnter == nil { self.onEnter = onEnter }
    }

    func replaceZones(_ zones: [GeoZone]) async {
        replaceCount += 1
        self.zones = zones
    }

    func removeAll() async {
        zones = []
    }

    func monitoredZoneIDs() async -> [String] {
        zones.map(\.id)
    }

    /// 시스템이 진입 이벤트를 보낸 것처럼 콜백을 부른다. 감시를 시작하지 않았으면 아무 일도 없다.
    func simulateEntry(_ zoneID: String) async {
        await onEnter?(zoneID)
    }
}
