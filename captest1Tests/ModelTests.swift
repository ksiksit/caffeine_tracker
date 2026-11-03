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

@MainActor
struct AddCaffeineViewModelTimeTests {

    @Test func newRecord_untouchedTime_usesNowAtSave() {
        let vm = AddCaffeineViewModel()
        vm.selectPreset(DrinkPreset.all[0])
        vm.selectedDate = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 2_000)
        #expect(vm.intakeTime(now: now) == now)
    }

    @Test func newRecord_editedTime_usesSelectedTime() {
        let vm = AddCaffeineViewModel()
        vm.selectPreset(DrinkPreset.all[0])
        let picked = Date().addingTimeInterval(-2 * 3600)
        vm.selectedDate = picked
        vm.isTimeEdited = true
        #expect(vm.resolve()?.timestamp == picked)
    }

    @Test func editRecord_usesRecordTime() {
        let vm = AddCaffeineViewModel()
        let recorded = Date().addingTimeInterval(-3 * 3600)
        vm.loadForEdit(.fixture(timestamp: recorded))
        #expect(vm.resolve()?.timestamp == recorded)
    }
}

@MainActor
struct AddCaffeineViewModelButtonTests {

    @Test func nothingSelected_asksToChoose() {
        let vm = AddCaffeineViewModel()
        #expect(vm.saveButtonTitle == "음료를 선택하세요")
        #expect(vm.canSave == false)
    }

    @Test func preset_showsNameAndAmount() {
        let vm = AddCaffeineViewModel()
        let preset = DrinkPreset.all[0]
        vm.selectPreset(preset)
        #expect(vm.saveButtonTitle == "\(preset.name) \(preset.caffeineAmount) mg 추가")
    }

    @Test func custom_withoutAmount_asksForAmount() {
        let vm = AddCaffeineViewModel()
        vm.activateCustomMode()
        #expect(vm.saveButtonTitle == "카페인 양을 입력하세요")
    }

    @Test func custom_withAmount_usesNameOrFallback() {
        let vm = AddCaffeineViewModel()
        vm.activateCustomMode()
        vm.customAmount = "120"
        #expect(vm.saveButtonTitle == "직접 입력 120 mg 추가")
        vm.customName = "콜드브루"
        #expect(vm.saveButtonTitle == "콜드브루 120 mg 추가")
    }

    @Test func editMode_saysSave() {
        let vm = AddCaffeineViewModel()
        vm.loadForEdit(.fixture())
        #expect(vm.saveButtonTitle == "저장")
    }
}
