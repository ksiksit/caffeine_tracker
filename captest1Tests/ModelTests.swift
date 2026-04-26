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

    @Test func isAsleep_correctForAllCases() {
        #expect(SleepStage.asleepCore.isAsleep == true)
        #expect(SleepStage.asleepDeep.isAsleep == true)
        #expect(SleepStage.asleepREM.isAsleep == true)
        #expect(SleepStage.asleepUnspecified.isAsleep == true)
        #expect(SleepStage.inBed.isAsleep == false)
        #expect(SleepStage.awake.isAsleep == false)
    }
}

struct SleepSummaryTests {

    private func makeRecord(stage: SleepStage, hours: Double) -> SleepRecord {
        let start = Date()
        let end = start.addingTimeInterval(hours * 3600)
        return SleepRecord(startDate: start, endDate: end, stage: stage)
    }

    @Test func totalSleepDuration_excludesNonSleep() {
        let summary = SleepSummary(date: Date(), records: [
            makeRecord(stage: .asleepDeep, hours: 2),
            makeRecord(stage: .asleepREM, hours: 1),
            makeRecord(stage: .inBed, hours: 0.5),
            makeRecord(stage: .awake, hours: 0.5),
        ])
        let totalHours = summary.totalSleepDuration / 3600
        #expect(totalHours == 3.0)
    }

    @Test func sleepEfficiency_zeroDivision() {
        let summary = SleepSummary(date: Date(), records: [])
        #expect(summary.sleepEfficiency == 0)
    }

    @Test func stageBreakdown_aggregatesCorrectly() {
        let summary = SleepSummary(date: Date(), records: [
            makeRecord(stage: .asleepDeep, hours: 1),
            makeRecord(stage: .asleepDeep, hours: 2),
            makeRecord(stage: .asleepREM, hours: 1),
        ])
        let breakdown = summary.stageBreakdown
        let deepEntry = breakdown.first { $0.stage == .asleepDeep }
        #expect(deepEntry != nil)
        #expect(deepEntry!.duration / 3600 == 3.0)
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
