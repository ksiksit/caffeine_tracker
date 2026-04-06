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

func koreanTimeLabel(for date: Date) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 0: return "자정"
    case 6: return "오전 6시"
    case 12: return "정오"
    case 18: return "오후 6시"
    default: return "\(hour)시"
    }
}

func effectiveHalfLife(base: Double, condition: CaffeineCondition) -> Double {
    base * condition.multiplier
}

func resolvedBedtimeDate(hour: Int, minute: Int) -> Date? {
    let calendar = Calendar.current
    let now = Date()
    var components = calendar.dateComponents([.year, .month, .day], from: now)
    components.hour = hour
    components.minute = minute

    guard let bedtime = calendar.date(from: components) else { return nil }

    if hour < AppConstants.Pharmacokinetics.chartStartHour {
        return calendar.date(byAdding: .day, value: 1, to: bedtime)
    }
    return bedtime
}
