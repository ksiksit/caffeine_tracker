//
//  GeofenceMonitor.swift
//  captest1
//
//  원형 구역 진입 감시(CoreLocation CLMonitor). 무엇을 감시할지·들어갔을 때 무엇을 할지는 모른다 — 구역 목록과 진입 콜백만 받는다.
//  동작 방식은 spikes/GeofenceSpike에서 검증했다:
//  - '항상' 권한 세션(CLServiceSession)을 쥐고 있어야 백그라운드·종료 상태에서도 진입 이벤트가 온다.
//  - 앱이 위치 이벤트로 다시 실행되면 **같은 이름**으로 모니터를 다시 만들어야 등록해 둔 구역과 이어진다.
//  - 모니터 이름은 영문자·숫자만(하이픈이 들어가면 'Monitor name is not valid'로 앱이 죽었다).
//

import CoreLocation
import UIKit

/// 감시할 원형 구역 하나. 식별자가 같으면 같은 구역으로 보고 다시 등록하지 않는다.
nonisolated struct GeoZone: Equatable, Hashable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let radius: Double
}

/// 지오펜스 포트. 테스트는 페이크로 바꿔 끼운다.
protocol GeofenceMonitoring: AnyObject {
    /// 감시를 시작(또는 재개)한다. 앱 실행마다 한 번, 진입 이벤트를 받을 곳을 넘긴다. 두 번째 호출부터는 무시.
    func start(onEnter: @escaping @MainActor (String) async -> Void)
    /// 감시 구역을 이 목록으로 맞춘다. 이미 있는 구역은 그대로 둬서, 안에 있는 사용자에게 진입 이벤트가 다시 가지 않게 한다.
    func replaceZones(_ zones: [GeoZone]) async
    func removeAll() async
    func monitoredZoneIDs() async -> [String]
}

final class GeofenceMonitor: GeofenceMonitoring {
    private static let monitorName = "CafeNearbyMonitor"

    private var serviceSession: CLServiceSession?
    private var eventTask: Task<Void, Never>?
    /// 모니터 생성은 비동기라 한 번만 만들고 모두 이것을 기다린다.
    private lazy var monitorTask: Task<CLMonitor, Never> = Task { await CLMonitor(Self.monitorName) }

    /// 교체가 겹치면(설정 토글 연타·동 선택 연속) 마지막 요청만 반영한다 — 같은 등록이 겹쳐 찍히지 않게.
    private var isReplacing = false
    private var pendingZones: [GeoZone]?

    func start(onEnter: @escaping @MainActor (String) async -> Void) {
        guard eventTask == nil else { return } // 같은 이름의 모니터를 두 번 구독하지 않는다
        serviceSession = CLServiceSession(authorization: .always)
        let monitorTask = monitorTask
        eventTask = Task {
            let monitor = await monitorTask.value
            do {
                for try await event in await monitor.events where event.state == .satisfied {
                    // 백그라운드로 깨어난 경우 실행 시간이 짧다 — 알림 등록이 끝날 때까지 시간을 조금 더 받는다.
                    let taskID = UIApplication.shared.beginBackgroundTask(withName: "cafe-nearby", expirationHandler: nil)
                    await onEnter(event.identifier)
                    UIApplication.shared.endBackgroundTask(taskID)
                }
            } catch {
                // 이벤트 스트림이 끝나면 다음 실행 때 다시 구독한다.
            }
        }
    }

    func replaceZones(_ zones: [GeoZone]) async {
        pendingZones = zones
        guard !isReplacing else { return }
        isReplacing = true
        defer { isReplacing = false }
        let monitor = await monitorTask.value
        while let target = pendingZones {
            pendingZones = nil
            let current = Set(await monitor.identifiers)
            let targetIDs = Set(target.map(\.id))
            for id in current.subtracting(targetIDs) {
                await monitor.remove(id)
            }
            for zone in target where !current.contains(zone.id) {
                let condition = CLMonitor.CircularGeographicCondition(
                    center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude),
                    radius: zone.radius)
                // 밖에 있다고 가정하고 등록 — 이미 안에 있으면 곧바로 진입 이벤트가 온다.
                await monitor.add(condition, identifier: zone.id, assuming: .unsatisfied)
            }
        }
    }

    func removeAll() async {
        await replaceZones([])
    }

    func monitoredZoneIDs() async -> [String] {
        let monitor = await monitorTask.value
        return Array(await monitor.identifiers)
    }
}
