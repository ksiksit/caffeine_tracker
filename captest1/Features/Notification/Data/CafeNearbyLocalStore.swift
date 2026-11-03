//
//  CafeNearbyLocalStore.swift
//  captest1
//
//  카페 근처 알림의 기기 저장소(UserDefaults). 앱이 꺼져 있다가 위치 이벤트로 깨어나면 네트워크 없이 이것만 보고 판정한다.
//  선택한 동은 기기에만 둔다 — 서버로 보내지 않는다.
//

import Foundation

final class CafeNearbyLocalStore {
    private enum Keys {
        static let isEnabled = "cafeNearby.isEnabled"
        static let selectedDongCodes = "cafeNearby.selectedDongCodes"
        static let windows = "cafeNearby.windows"
        static let lastAlertAt = "cafeNearby.lastAlertAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 설정 토글의 기기 사본. 백그라운드 실행 때 설정을 서버에서 받지 않고도 감시를 재개할지 정한다.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    var selectedDongCodes: [String] {
        get { defaults.stringArray(forKey: Keys.selectedDongCodes) ?? [] }
        set { defaults.set(newValue, forKey: Keys.selectedDongCodes) }
    }

    /// 마지막으로 받은 금지 구간. 디코딩에 실패하면(형식 변경) 빈 목록 — 다음 계획 조회 때 채워진다.
    var windows: [CafeNearbyWindowDTO] {
        get {
            guard let data = defaults.data(forKey: Keys.windows) else { return [] }
            return (try? JSONDecoder().decode([CafeNearbyWindowDTO].self, from: data)) ?? []
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Keys.windows) }
    }

    var lastAlertAt: Date? {
        get { defaults.object(forKey: Keys.lastAlertAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastAlertAt) }
    }

    /// 로그아웃 — 이전 계정의 선택·구간·알림 기록을 모두 지운다.
    func reset() {
        for key in [Keys.isEnabled, Keys.selectedDongCodes, Keys.windows, Keys.lastAlertAt] {
            defaults.removeObject(forKey: key)
        }
    }
}
