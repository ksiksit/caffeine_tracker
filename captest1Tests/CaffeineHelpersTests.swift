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
}
