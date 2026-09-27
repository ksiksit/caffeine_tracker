//
//  Fixtures.swift
//  captest1Tests
//
//  서버 DTO 고정값. 필드 구성은 서버 docs/api.md 기준.
//

import Foundation
@testable import captest1

extension CaffeineTodayResponse {
    static func fixture(
        now: Date = Date(),
        cutoff: CutoffDTO = CutoffDTO(status: "SAFE_ANYTIME", cutoff: nil, existingAtBedtime: nil),
        records: [CaffeineRecordDTO] = []
    ) -> CaffeineTodayResponse {
        CaffeineTodayResponse(
            now: now,
            bedtime: now.addingTimeInterval(6 * 3600),
            records: records,
            todayTotal: records.reduce(0) { $0 + $1.amount },
            overDailyLimit: false,
            chart: [],
            currentResidual: 0,
            predictedAtBedtime: 0,
            cutoff: cutoff,
            effectiveHalfLifeHours: 5,
            referenceDoseMg: 75
        )
    }
}

extension CaffeineRecordDTO {
    static func fixture(id: Int64 = 1, amount: Int = 150, drinkName: String = "아메리카노", timestamp: Date = Date()) -> CaffeineRecordDTO {
        CaffeineRecordDTO(id: id, amount: amount, drinkName: drinkName, timestamp: timestamp)
    }
}

extension LearningDashboardResponse {
    static func fixture(count: Int = 0) -> LearningDashboardResponse {
        LearningDashboardResponse(
            count: count,
            latest: nil,
            observations: [],
            calibration: Calibration(points: [], rSquared: nil, rmse: 0, domainLower: 0, domainUpper: 60),
            residualHistogram: [],
            solHistogram: []
        )
    }
}

extension SettingsResponse {
    static func fixture(
        halfLife: Double = 5.0,
        condition: Int = 0,
        bedtimeHour: Int = 23,
        bedtimeMinute: Int = 0,
        referenceDoseMg: Int = 75,
        isLearningEnabled: Bool = true,
        learnedMean: Double = 5.0,
        learnedVariance: Double = 2.25,
        lastLearnedDate: String? = nil,
        notifications: NotificationSettingsDTO = NotificationSettingsDTO(cutoff: true, bedtimeResidual: true, recordReminder: true)
    ) -> SettingsResponse {
        SettingsResponse(
            halfLife: halfLife, condition: condition, bedtimeHour: bedtimeHour, bedtimeMinute: bedtimeMinute,
            referenceDoseMg: referenceDoseMg, isLearningEnabled: isLearningEnabled,
            learnedMean: learnedMean, learnedVariance: learnedVariance, lastLearnedDate: lastLearnedDate,
            inferredBaseHalfLife: isLearningEnabled ? learnedMean : halfLife,
            effectiveHalfLifeHours: (isLearningEnabled ? learnedMean : halfLife)
                * (CaffeineCondition(rawValue: condition) ?? .none).multiplier,
            notifications: notifications
        )
    }
}

extension NotificationItemDTO {
    static func fixture(type: String = "CUTOFF", fireAt: Date = Date().addingTimeInterval(3600),
                        title: String = "섭취 마감 30분 전", body: String = "본문") -> NotificationItemDTO {
        NotificationItemDTO(type: type, fireAt: fireAt, title: title, body: body)
    }
}

extension SleepSummaryResponse {
    static let noData = SleepSummaryResponse(
        date: nil, hasData: false, bedtimeStart: nil, records: [],
        totalSleepSeconds: 0, timeInBedSeconds: 0, sleepEfficiency: 0,
        sleepOnsetLatencySeconds: nil, stageBreakdown: []
    )

    static func fixture(
        date: String,
        totalSleepSeconds: Double = 6 * 3600,
        timeInBedSeconds: Double = 8 * 3600,
        sleepOnsetLatencySeconds: Double? = 900,
        stageBreakdown: [SleepStageItem] = [
            SleepStageItem(hkValue: 4, durationSeconds: 3600),   // asleepDeep
            SleepStageItem(hkValue: 5, durationSeconds: 1800),   // asleepREM
        ]
    ) -> SleepSummaryResponse {
        SleepSummaryResponse(
            date: date, hasData: true, bedtimeStart: nil, records: [],
            totalSleepSeconds: totalSleepSeconds, timeInBedSeconds: timeInBedSeconds,
            sleepEfficiency: timeInBedSeconds > 0 ? totalSleepSeconds / timeInBedSeconds : 0,
            sleepOnsetLatencySeconds: sleepOnsetLatencySeconds, stageBreakdown: stageBreakdown
        )
    }
}
