//
//  CafeNearbyGateTests.swift
//  captest1Tests
//
//  구역 진입 순간의 판정: 금지 구간 [activeFrom, activeUntil) 안인가, 전체 재알림 간격 60분이 지났나.
//

import Foundation
import Testing
@testable import captest1

struct CafeNearbyGateTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func window(from: TimeInterval, until: TimeInterval, reason: String = "CUTOFF_PASSED") -> CafeNearbyWindow {
        CafeNearbyWindow(reason: reason, activeFrom: t0.addingTimeInterval(from), activeUntil: t0.addingTimeInterval(until),
                         title: "카페 근처예요", body: reason)
    }

    @Test func insideWindow_noPreviousAlert_notifies() {
        let w = window(from: -3600, until: 3600)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: nil) == w)
    }

    @Test func beforeWindow_doesNotNotify() {
        let w = window(from: 60, until: 3600)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: nil) == nil)
    }

    @Test func afterWindow_doesNotNotify() {
        let w = window(from: -7200, until: -60)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: nil) == nil)
    }

    @Test func activeFrom_isInclusive() {
        let w = window(from: 0, until: 3600)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: nil) == w)
    }

    @Test func activeUntil_isExclusive() {
        let w = window(from: -3600, until: 0)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: nil) == nil)
    }

    @Test func noWindows_doesNotNotify() {
        #expect(CafeNearbyGate.decide(now: t0, windows: [], lastAlertAt: nil) == nil)
    }

    @Test func withinCooldown_suppresses() {
        let w = window(from: -3600, until: 3600)
        let last = t0.addingTimeInterval(-59 * 60)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: last) == nil)
    }

    @Test func afterCooldown_notifiesAgain() {
        let w = window(from: -7200, until: 3600)
        let last = t0.addingTimeInterval(-60 * 60)
        #expect(CafeNearbyGate.decide(now: t0, windows: [w], lastAlertAt: last) == w)
    }

    @Test func picksTheWindowContainingNow() {
        // 서버는 오늘 구간과 기록 없는 다음 날 기본 구간을 함께 준다.
        let today = window(from: -86_400, until: -3600, reason: "DAILY_LIMIT_EXCEEDED")
        let tomorrow = window(from: -60, until: 86_400, reason: "CUTOFF_PASSED")
        #expect(CafeNearbyGate.decide(now: t0, windows: [today, tomorrow], lastAlertAt: nil) == tomorrow)
    }

    @Test func windowFromDTO_keepsServerFields() {
        let dto = CafeNearbyWindowDTO(reason: "ALREADY_EXCEEDED", activeFrom: t0, activeUntil: t0.addingTimeInterval(60),
                                      title: "카페 근처예요", body: "본문")
        let w = CafeNearbyWindow(dto: dto)
        #expect(w.reason == "ALREADY_EXCEEDED" && w.title == "카페 근처예요" && w.body == "본문")
        #expect(w.activeFrom == t0 && w.activeUntil == t0.addingTimeInterval(60))
    }
}
