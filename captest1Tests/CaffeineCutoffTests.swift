//
//  CaffeineCutoffTests.swift
//  captest1Tests
//
//  즉시 미리보기·차트 보조 함수(Features/Caffeine/CaffeineCutoff.swift) 검증.
//

import Foundation
import Testing
@testable import captest1

struct CaffeineCutoffTests {

    // MARK: - koreanTimeLabel

    @Test func koreanTimeLabel_midnight() {
        let midnight = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        #expect(koreanTimeLabel(for: midnight) == "자정")
    }

    @Test func koreanTimeLabel_morning() {
        let morning = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!
        #expect(koreanTimeLabel(for: morning) == "오전 6시")
    }

    @Test func koreanTimeLabel_noon() {
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        #expect(koreanTimeLabel(for: noon) == "정오")
    }

    @Test func koreanTimeLabel_evening() {
        let evening = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        #expect(koreanTimeLabel(for: evening) == "오후 6시")
    }

    @Test func koreanTimeLabel_defaultHour() {
        let nineAM = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        #expect(koreanTimeLabel(for: nineAM) == "9시")
    }
}
