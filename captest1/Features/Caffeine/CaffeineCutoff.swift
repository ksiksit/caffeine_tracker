//
//  CaffeineCutoff.swift
//  captest1
//
//  카페인 추가 화면의 즉시 미리보기용 마감시각 계산(서버 calc의 로컬 미러)과 차트 보조 함수.
//  filterTodayRecords·calculateTotalCaffeine·isOverDailyLimit·toDoses는 서버 이관 잔재로 단계 6에서 삭제 예정.
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

enum CaffeineCutoffResult {
    case safeAnytime
    case cutoff(Date)
    case alreadyExceeded(Double)
}

func caffeineCutoffTime(
    currentDoses: [CaffeineKineticsCalculator.Dose],
    bedtime: Date,
    referenceDoseMg: Double,
    halfLifeHours: Double,
    safeThresholdMg: Double = AppConstants.Caffeine.bedtimeSafeThresholdMg
) -> CaffeineCutoffResult {
    guard referenceDoseMg > 0, halfLifeHours > 0 else { return .safeAnytime }

    let existingAtBedtime = CaffeineKineticsCalculator.totalRemaining(
        at: bedtime, doses: currentDoses, halfLifeHours: halfLifeHours
    )

    let headroom = safeThresholdMg - existingAtBedtime
    if headroom <= 0 {
        return .alreadyExceeded(existingAtBedtime)
    }
    if headroom >= referenceDoseMg {
        return .safeAnytime
    }

    let ke = log(2) / halfLifeHours
    let hoursBeforeBedtime = log(referenceDoseMg / headroom) / ke
    let cutoff = bedtime.addingTimeInterval(-hoursBeforeBedtime * 3600)
    return .cutoff(cutoff)
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
