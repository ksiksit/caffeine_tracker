//
//  Constants.swift
//  captest1
//

import Foundation

enum AppConstants {
    enum Caffeine {
        static let dailyRecommendedLimitMg = 400
        static let maxCustomAmountMg = 10_000
    }

    enum Sleep {
        static let recentHistoryDays = 7
        static let windowStartHour = 18
        static let windowEndHour = 12
    }

    enum Pharmacokinetics {
        static let defaultHalfLifeHours: Double = 5.0
        static let minHalfLifeHours: Double = 3.0
        static let maxHalfLifeHours: Double = 7.0
        static let chartIntervalMinutes: Int = 15
        static let chartStartHour: Int = 5
        static let chartForwardHours: Int = 24
    }
}
