//
//  SleepModels.swift
//  captest1
//
//  수면 탭 표시 모델. 총수면·침대시간·효율·단계별 합계·SOL은 서버 SleepSummaryCalc가 계산한 값을 그대로 담으며
//  앱은 재계산하지 않는다(thin-client). 단계(hkValue) → SleepStage 복원과 표시 포맷만 여기서 한다.
//

import SwiftUI
import HealthKit

nonisolated enum SleepStage: CaseIterable {
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
}

/// 서버 `SleepSummaryResponse`와 1:1인 표시 모델.
nonisolated struct SleepSummary: Identifiable {
    let id = UUID()
    /// 요약 기준 날짜(그 밤이 끝나는 아침).
    let date: Date
    let bedtimeStart: Date?
    let totalSleepDuration: TimeInterval
    /// 최초 시작~최후 끝 스팬(서버 정의, IN_BED 합이 아님).
    let timeInBed: TimeInterval
    let sleepEfficiency: Double
    let sleepOnsetLatency: TimeInterval?
    /// 지속시간 > 0인 단계만, SleepStage 선언 순서(서버가 정렬).
    let stageBreakdown: [(stage: SleepStage, duration: TimeInterval)]

    init(date: Date, response: SleepSummaryResponse) {
        self.date = date
        bedtimeStart = response.bedtimeStart
        totalSleepDuration = response.totalSleepSeconds
        timeInBed = response.timeInBedSeconds
        sleepEfficiency = response.sleepEfficiency
        sleepOnsetLatency = response.sleepOnsetLatencySeconds
        stageBreakdown = response.stageBreakdown.map { (SleepStage(from: $0.hkValue), $0.durationSeconds) }
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
