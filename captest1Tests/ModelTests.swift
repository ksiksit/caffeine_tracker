//
//  ModelTests.swift
//  captest1Tests
//

import Foundation
import Testing
import HealthKit
@testable import captest1

struct HealthKitAccessStateTests {

    @Test func unavailableDevice_returnsUnavailable() {
        let state = HealthKitManager.accessState(
            isAvailable: false,
            requestStatus: .unnecessary,
            hasRequestedBefore: true
        )

        #expect(state == .unavailable)
    }

    @Test func shouldRequest_returnsNeedsRequest() {
        let state = HealthKitManager.accessState(
            isAvailable: true,
            requestStatus: .shouldRequest,
            hasRequestedBefore: true
        )

        #expect(state == .needsRequest)
    }

    @Test func unnecessary_returnsRequestCompleted() {
        let state = HealthKitManager.accessState(
            isAvailable: true,
            requestStatus: .unnecessary,
            hasRequestedBefore: false
        )

        #expect(state == .requestCompleted)
    }

    @Test func unknownWithPriorRequest_returnsRequestCompleted() {
        let state = HealthKitManager.accessState(
            isAvailable: true,
            requestStatus: .unknown,
            hasRequestedBefore: true
        )

        #expect(state == .requestCompleted)
    }

    @Test func unknownWithoutPriorRequest_returnsNeedsRequest() {
        let state = HealthKitManager.accessState(
            isAvailable: true,
            requestStatus: .unknown,
            hasRequestedBefore: false
        )

        #expect(state == .needsRequest)
    }
}

struct SleepStageTests {

    @Test func initFromHKValue_mapsCorrectly() {
        #expect(SleepStage(from: HKCategoryValueSleepAnalysis.inBed.rawValue) == .inBed)
        #expect(SleepStage(from: HKCategoryValueSleepAnalysis.awake.rawValue) == .awake)
        #expect(SleepStage(from: HKCategoryValueSleepAnalysis.asleepCore.rawValue) == .asleepCore)
        #expect(SleepStage(from: HKCategoryValueSleepAnalysis.asleepDeep.rawValue) == .asleepDeep)
        #expect(SleepStage(from: HKCategoryValueSleepAnalysis.asleepREM.rawValue) == .asleepREM)
    }

    @Test func unknownValue_defaultsToUnspecified() {
        #expect(SleepStage(from: 999) == .asleepUnspecified)
    }
}

struct SleepSummaryTests {

    /// 서버 SleepSummaryCalc 결과를 그대로 담는지(재계산 없음) 확인.
    private static let response = SleepSummaryResponse(
        date: "2026-06-01", hasData: true, bedtimeStart: nil, records: [],
        totalSleepSeconds: 6 * 3600, timeInBedSeconds: 8 * 3600, sleepEfficiency: 0.75,
        sleepOnsetLatencySeconds: 900,
        stageBreakdown: [
            SleepStageItem(hkValue: HKCategoryValueSleepAnalysis.asleepDeep.rawValue, durationSeconds: 3600),
            SleepStageItem(hkValue: HKCategoryValueSleepAnalysis.asleepREM.rawValue, durationSeconds: 1800),
        ]
    )

    @Test func init_mapsServerFieldsWithoutRecomputing() {
        let summary = SleepSummary(date: Date(), response: Self.response)
        #expect(summary.totalSleepDuration == 6 * 3600)
        #expect(summary.timeInBed == 8 * 3600)
        #expect(summary.sleepEfficiency == 0.75)
        #expect(summary.sleepOnsetLatency == 900)
        #expect(summary.stageBreakdown.map(\.stage) == [.asleepDeep, .asleepREM])
        #expect(summary.stageBreakdown.map(\.duration) == [3600, 1800])
    }

    @Test func formatDuration_hoursAndMinutes() {
        #expect(SleepSummary.formatDuration(7200 + 1800) == "2시간 30분")
    }

    @Test func formatDuration_minutesOnly() {
        #expect(SleepSummary.formatDuration(2700) == "45분")
    }
}

struct DrinkPresetTests {

    @Test func allPresets_havePositiveAmounts() {
        for preset in DrinkPreset.all {
            #expect(preset.caffeineAmount > 0, "Preset '\(preset.name)' has non-positive amount")
        }
    }

    @Test func allPresets_haveNonEmptyNames() {
        for preset in DrinkPreset.all {
            #expect(!preset.name.isEmpty)
        }
    }

    @Test func allPresets_haveUniqueNames() {
        let names = DrinkPreset.all.map(\.name)
        #expect(Set(names).count == names.count)
    }
}
