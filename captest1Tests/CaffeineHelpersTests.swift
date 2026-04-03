//
//  CaffeineHelpersTests.swift
//  captest1Tests
//

import Foundation
import Testing
@testable import captest1

struct CaffeineHelpersTests {

    @Test func filterTodayRecords_onlyIncludesToday() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let todayRecord = CaffeineRecord(amount: 100, drinkName: "커피", timestamp: now)
        let yesterdayRecord = CaffeineRecord(amount: 200, drinkName: "라떼", timestamp: yesterday)

        let result = filterTodayRecords([todayRecord, yesterdayRecord])
        #expect(result.count == 1)
        #expect(result[0].amount == 100)
    }

    @Test func filterTodayRecords_emptyInput() {
        let result = filterTodayRecords([])
        #expect(result.isEmpty)
    }

    @Test func calculateTotalCaffeine_sumsCorrectly() {
        let records = [
            CaffeineRecord(amount: 150, drinkName: "아메리카노"),
            CaffeineRecord(amount: 75, drinkName: "에스프레소"),
        ]
        #expect(calculateTotalCaffeine(records) == 225)
    }

    @Test func calculateTotalCaffeine_emptyArray() {
        #expect(calculateTotalCaffeine([]) == 0)
    }

    @Test func isOverDailyLimit_boundaryValues() {
        #expect(isOverDailyLimit(400) == false)
        #expect(isOverDailyLimit(401) == true)
        #expect(isOverDailyLimit(0) == false)
    }

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
