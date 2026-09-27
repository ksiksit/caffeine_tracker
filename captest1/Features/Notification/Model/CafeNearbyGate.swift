//
//  CafeNearbyGate.swift
//  captest1
//
//  카페 구역에 들어선 순간 알림을 띄울지 정하는 순수 판정. 네트워크 없이 기기에 저장한 금지 구간과 마지막 알림 시각만 본다.
//  "언제"(금지 구간)는 서버가 계산하고, 여기서는 "지금이 그 구간인가"와 재알림 간격만 판단한다.
//

import Foundation

/// 금지 구간 [activeFrom, activeUntil). 문구는 서버가 만든 그대로 쓴다.
nonisolated struct CafeNearbyWindow: Equatable, Sendable {
    let reason: String
    let activeFrom: Date
    let activeUntil: Date
    let title: String
    let body: String

    init(reason: String, activeFrom: Date, activeUntil: Date, title: String, body: String) {
        self.reason = reason
        self.activeFrom = activeFrom
        self.activeUntil = activeUntil
        self.title = title
        self.body = body
    }

    init(dto: CafeNearbyWindowDTO) {
        self.init(reason: dto.reason, activeFrom: dto.activeFrom, activeUntil: dto.activeUntil,
                  title: dto.title, body: dto.body)
    }

    func contains(_ date: Date) -> Bool {
        activeFrom <= date && date < activeUntil
    }
}

nonisolated enum CafeNearbyGate {
    /// 재알림 간격. 구역과 무관하게 전체에서 한 번 — 카페 거리를 걸어가며 구역 여러 개를 지나도 한 번만 울린다.
    static let cooldown: TimeInterval = 60 * 60

    /// 지금 울려야 하면 그 구간을, 아니면 nil.
    static func decide(now: Date, windows: [CafeNearbyWindow], lastAlertAt: Date?) -> CafeNearbyWindow? {
        guard let window = windows.first(where: { $0.contains(now) }) else { return nil }
        if let lastAlertAt, now.timeIntervalSince(lastAlertAt) < cooldown { return nil }
        return window
    }
}
