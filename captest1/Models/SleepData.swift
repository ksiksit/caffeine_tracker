//
//  SleepData.swift
//  captest1
//

import SwiftUI
import HealthKit

enum SleepStage: CaseIterable {
    case inBed
    case awake
    case asleepCore
    case asleepDeep
    case asleepREM
    case asleepUnspecified

    var displayName: String {
        switch self {
        case .inBed: String(localized: "sleep.stage.inBed")
        case .awake: String(localized: "sleep.stage.awake")
        case .asleepCore: String(localized: "sleep.stage.core")
        case .asleepDeep: String(localized: "sleep.stage.deep")
        case .asleepREM: String(localized: "sleep.stage.rem")
        case .asleepUnspecified: String(localized: "sleep.stage.unspecified")
        }
    }

    var color: Color {
        switch self {
        case .inBed: .gray
        case .awake: .orange
        case .asleepCore: .blue
        case .asleepDeep: .indigo
        case .asleepREM: .purple
        case .asleepUnspecified: .cyan
        }
    }

    init(from hkValue: Int) {
        switch hkValue {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            self = .inBed
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            self = .awake
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            self = .asleepCore
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            self = .asleepDeep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            self = .asleepREM
        default:
            self = .asleepUnspecified
        }
    }

    var isAsleep: Bool {
        switch self {
        case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
            true
        default:
            false
        }
    }
}

struct SleepRecord: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let stage: SleepStage

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

struct SleepSummary: Identifiable {
    let id = UUID()
    let date: Date
    let records: [SleepRecord]
    let bedtimeStart: Date?

    init(date: Date, records: [SleepRecord], bedtimeStart: Date? = nil) {
        self.date = date
        self.records = records
        self.bedtimeStart = bedtimeStart
    }

    var totalSleepDuration: TimeInterval {
        records.filter { $0.stage.isAsleep }.reduce(0) { $0 + $1.duration }
    }

    var timeInBed: TimeInterval {
        guard let earliest = records.map(\.startDate).min(),
              let latest = records.map(\.endDate).max() else { return 0 }
        return latest.timeIntervalSince(earliest)
    }

    var sleepEfficiency: Double {
        guard timeInBed > 0 else { return 0 }
        return totalSleepDuration / timeInBed
    }

    /// 첫 inBed 시작 ~ 첫 asleep* 시작 사이의 잠복 시간(초).
    /// inBed 기록이 없거나 음수면 nil. (학습용 SOL은 서버 BedtimeExtractor가 별도 계산)
    var sleepOnsetLatency: TimeInterval? {
        let fallbackInBedStart = records
            .filter { $0.stage == .inBed }
            .map(\.startDate)
            .min()
        guard let inBedStart = bedtimeStart ?? fallbackInBedStart,
              let firstAsleep = records
                .filter({ $0.stage.isAsleep })
                .map(\.startDate).min()
        else { return nil }
        let latency = firstAsleep.timeIntervalSince(inBedStart)
        return latency >= 0 ? latency : nil
    }

    var stageBreakdown: [(stage: SleepStage, duration: TimeInterval)] {
        var breakdown: [SleepStage: TimeInterval] = [:]
        for record in records {
            breakdown[record.stage, default: 0] += record.duration
        }
        return SleepStage.allCases.compactMap { stage in
            guard let duration = breakdown[stage], duration > 0 else { return nil }
            return (stage, duration)
        }
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return String(localized: "\(hours)시간 \(minutes)분")
        }
        return String(localized: "\(minutes)분")
    }
}
