//
//  LocationPermissionManager.swift
//  captest1
//
//  위치 권한 상태만 담당한다(Core). 위치 값은 읽지 않고, 어디에도 보내지 않는다 — 지오펜스 판정은 시스템이 기기 안에서 한다.
//  카페 근처 알림은 앱이 꺼져 있을 때도 울려야 하므로 '항상 허용'과 '정확한 위치'가 필요하다.
//  iOS는 '항상'을 바로 묻지 못한다: 먼저 '사용하는 동안'을 받고, 그다음 '항상'으로 올리는 창을 한 번 띄울 수 있다.
//

import CoreLocation

nonisolated enum LocationPermission: Equatable, Sendable {
    case notDetermined
    case whenInUse
    case always
    /// 거부·제한·기기 전체 위치 서비스 꺼짐. 설정 앱에서만 바꿀 수 있다.
    case denied

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorizedWhenInUse: self = .whenInUse
        case .authorizedAlways: self = .always
        case .denied, .restricted: self = .denied
        @unknown default: self = .denied
        }
    }
}

@MainActor
@Observable
final class LocationPermissionManager: NSObject {
    private(set) var permission: LocationPermission
    /// 대략적 위치면 지오펜스가 동작하지 않는다.
    private(set) var isFullAccuracy: Bool
    /// '항상'으로 올리는 창을 이미 띄웠는지. iOS는 두 번째부터 창 없이 무시하므로, 그때는 설정 앱으로 안내한다.
    private(set) var hasAskedAlways: Bool {
        didSet { defaults.set(hasAskedAlways, forKey: Self.hasAskedAlwaysKey) }
    }

    /// 카페 근처 알림이 동작할 수 있는 상태.
    var isReadyForGeofence: Bool { permission == .always && isFullAccuracy }

    private static let hasAskedAlwaysKey = "hasAskedLocationAlways"
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        permission = LocationPermission(manager.authorizationStatus)
        isFullAccuracy = manager.accuracyAuthorization == .fullAccuracy
        hasAskedAlways = defaults.bool(forKey: Self.hasAskedAlwaysKey)
        super.init()
        manager.delegate = self
    }

    /// 지금 단계에서 띄울 수 있는 다음 권한 창을 띄운다. 띄울 창이 없으면(거부·이미 물어봄) false — 설정 앱으로 안내할 때.
    @discardableResult
    func requestNextStep() -> Bool {
        switch permission {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return true
        case .whenInUse where !hasAskedAlways:
            hasAskedAlways = true
            manager.requestAlwaysAuthorization()
            return true
        default:
            return false
        }
    }

    func refresh() {
        permission = LocationPermission(manager.authorizationStatus)
        isFullAccuracy = manager.accuracyAuthorization == .fullAccuracy
    }
}

extension LocationPermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }
}
