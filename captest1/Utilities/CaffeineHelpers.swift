//
//  CaffeineHelpers.swift
//  captest1
//

import Foundation

func filterTodayRecords(_ records: [CaffeineRecord]) -> [CaffeineRecord] {
    let startOfDay = Calendar.current.startOfDay(for: Date())
        .addingTimeInterval(Double(AppConstants.Pharmacokinetics.chartStartHour) * 3600)
    return records.filter { $0.timestamp >= startOfDay }
}

func calculateTotalCaffeine(_ records: [CaffeineRecord]) -> Int {
    records.reduce(0) { $0 + $1.amount }
}

func isOverDailyLimit(_ total: Int) -> Bool {
    total > AppConstants.Caffeine.dailyRecommendedLimitMg
}

func toDoses(_ records: [CaffeineRecord]) -> [CaffeineKineticsCalculator.Dose] {
    records.map {
        CaffeineKineticsCalculator.Dose(timestamp: $0.timestamp, amountMg: Double($0.amount))
    }
}
