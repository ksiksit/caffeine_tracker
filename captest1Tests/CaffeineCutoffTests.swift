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

    // MARK: - resolvedBedtimeDate

    @Test func resolvedBedtimeDate_eveningHour_returnsToday() {
        let result = resolvedBedtimeDate(hour: 23, minute: 0)
        #expect(result != nil)
        let components = Calendar.current.dateComponents([.hour, .minute], from: result!)
        #expect(components.hour == 23)
        #expect(components.minute == 0)
        // 오늘 날짜여야 함
        let today = Calendar.current.startOfDay(for: Date())
        let resultDay = Calendar.current.startOfDay(for: result!)
        #expect(resultDay == today)
    }

    @Test func resolvedBedtimeDate_earlyMorning_returnsTomorrow() {
        let result = resolvedBedtimeDate(hour: 1, minute: 30)
        #expect(result != nil)
        let components = Calendar.current.dateComponents([.hour, .minute], from: result!)
        #expect(components.hour == 1)
        #expect(components.minute == 30)
        // 내일 날짜여야 함 (chartStartHour=5 미만이므로)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        let resultDay = Calendar.current.startOfDay(for: result!)
        #expect(resultDay == tomorrow)
    }

    @Test func resolvedBedtimeDate_boundaryAtChartStartHour_returnsToday() {
        // hour=5는 chartStartHour(5)와 같으므로 5 < 5 = false → 오늘
        let result = resolvedBedtimeDate(hour: 5, minute: 0)
        #expect(result != nil)
        let today = Calendar.current.startOfDay(for: Date())
        let resultDay = Calendar.current.startOfDay(for: result!)
        #expect(resultDay == today)
    }
}
