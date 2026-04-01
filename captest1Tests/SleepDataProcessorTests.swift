//
//  SleepDataProcessorTests.swift
//  captest1Tests
//

import Foundation
import HealthKit
import Testing
@testable import captest1

struct MockSleepSample: SleepSampleProtocol {
    let startDate: Date
    let endDate: Date
    let sleepValue: Int
}

struct SleepDataProcessorTests {

    /// 기준일 오후 6시(18:00)부터의 오프셋(분)으로 날짜 생성.
    /// 예: offset(0) = 18:00, offset(240) = 22:00, offset(360) = 00:00(다음날), offset(780) = 07:00(다음날)
    private func offset(_ minutes: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        return base.addingTimeInterval(Double(minutes) * 60)
    }

    /// 편의 메서드: 시:분을 오프셋으로 변환 (18시 기준)
    /// hour 18 = offset 0, hour 22 = offset 240, hour 0(다음날) = offset 360, hour 7(다음날) = offset 780
    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        let minutesFrom18: Int
        if hour >= 18 {
            minutesFrom18 = (hour - 18) * 60 + minute
        } else {
            minutesFrom18 = (hour + 6) * 60 + minute  // 다음날
        }
        return offset(minutesFrom18)
    }

    // MARK: - mergeSamples 테스트

    @Test func mergeSamples_emptyInput_returnsEmpty() {
        let result = SleepDataProcessor.mergeSamples([MockSleepSample]())
        #expect(result.isEmpty)
    }

    @Test func mergeSamples_singleSample_returnsSame() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 3),
        ]
        let result = SleepDataProcessor.mergeSamples(samples)
        #expect(result.count == 1)
        #expect(result[0].start == time(22))
        #expect(result[0].end == time(23))
        #expect(result[0].sleepValue == 3)
    }

    @Test func mergeSamples_adjacentNoOverlap_keepsAll() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 3),
            MockSleepSample(startDate: time(23), endDate: time(0), sleepValue: 4),
        ]
        let result = SleepDataProcessor.mergeSamples(samples)
        #expect(result.count == 2)
        #expect(result[0].sleepValue == 3)
        #expect(result[1].sleepValue == 4)
    }

    @Test func mergeSamples_adjacentSameStage_merged() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 3),
            MockSleepSample(startDate: time(23), endDate: time(0), sleepValue: 3),
        ]
        let result = SleepDataProcessor.mergeSamples(samples)
        #expect(result.count == 1)
        #expect(result[0].start == time(22))
        #expect(result[0].end == time(0))
        #expect(result[0].sleepValue == 3)
    }

    @Test func mergeSamples_fullOverlap_keepsHigherPriority() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 0), // inBed
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 5), // asleepDeep
        ]
        let result = SleepDataProcessor.mergeSamples(samples)
        #expect(result.count == 1)
        #expect(result[0].sleepValue == 5)
    }

    @Test func mergeSamples_partialOverlap_preservesNonOverlappingPortion() {
        // iPhone: inBed [22:00 - 07:00]
        // Watch:  core  [23:00 - 01:00]
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(7), sleepValue: 0),
            MockSleepSample(startDate: time(23), endDate: time(1), sleepValue: 3),
        ]
        let result = SleepDataProcessor.mergeSamples(samples)

        #expect(result.count == 3)

        #expect(result[0].start == time(22))
        #expect(result[0].end == time(23))
        #expect(result[0].sleepValue == 0)  // inBed 보존

        #expect(result[1].start == time(23))
        #expect(result[1].end == time(1))
        #expect(result[1].sleepValue == 3)  // core 우선

        #expect(result[2].start == time(1))
        #expect(result[2].end == time(7))
        #expect(result[2].sleepValue == 0)  // inBed 보존
    }

    @Test func mergeSamples_iPhoneWatchRealisticScenario() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(6), sleepValue: 0),          // iPhone inBed
            MockSleepSample(startDate: time(22, 30), endDate: time(23, 45), sleepValue: 3), // Watch core
            MockSleepSample(startDate: time(23, 45), endDate: time(0, 30), sleepValue: 5),  // Watch REM
            MockSleepSample(startDate: time(0, 30), endDate: time(2), sleepValue: 4),       // Watch deep
            MockSleepSample(startDate: time(2), endDate: time(4), sleepValue: 3),            // Watch core
            MockSleepSample(startDate: time(4), endDate: time(4, 15), sleepValue: 2),        // Watch awake
            MockSleepSample(startDate: time(4, 15), endDate: time(6), sleepValue: 3),        // Watch core
        ]
        let result = SleepDataProcessor.mergeSamples(samples)

        // 22:00-22:30 inBed이 보존되어야 함
        #expect(result[0].start == time(22))
        #expect(result[0].end == time(22, 30))
        #expect(result[0].sleepValue == 0)  // inBed

        // 22:30-23:45 core
        #expect(result[1].start == time(22, 30))
        #expect(result[1].end == time(23, 45))
        #expect(result[1].sleepValue == 3)

        // 23:45-00:30 REM
        #expect(result[2].start == time(23, 45))
        #expect(result[2].end == time(0, 30))
        #expect(result[2].sleepValue == 5)

        // 총 7개 구간 (inBed, core, REM, deep, core, awake, core)
        #expect(result.count == 7)
    }

    @Test func mergeSamples_gapBetweenSamples_gapPreserved() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 3),
            MockSleepSample(startDate: time(1), endDate: time(2), sleepValue: 4),
        ]
        let result = SleepDataProcessor.mergeSamples(samples)
        #expect(result.count == 2)
        #expect(result[0].end == time(23))
        #expect(result[1].start == time(1))
    }

    @Test func mergeSamples_tripleOverlap_highestPriorityWins() {
        let samples = [
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 0), // inBed
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 3), // core
            MockSleepSample(startDate: time(22), endDate: time(23), sleepValue: 5), // deep
        ]
        let result = SleepDataProcessor.mergeSamples(samples)
        #expect(result.count == 1)
        #expect(result[0].sleepValue == 5)
    }

    // MARK: - stagePriority 테스트

    @Test func stagePriority_correctOrder() {
        let deepPriority = SleepDataProcessor.stagePriority(for: HKCategoryValueSleepAnalysis.asleepDeep.rawValue)
        let remPriority = SleepDataProcessor.stagePriority(for: HKCategoryValueSleepAnalysis.asleepREM.rawValue)
        let corePriority = SleepDataProcessor.stagePriority(for: HKCategoryValueSleepAnalysis.asleepCore.rawValue)
        let awakePriority = SleepDataProcessor.stagePriority(for: HKCategoryValueSleepAnalysis.awake.rawValue)
        let inBedPriority = SleepDataProcessor.stagePriority(for: HKCategoryValueSleepAnalysis.inBed.rawValue)

        #expect(deepPriority > remPriority)
        #expect(remPriority > corePriority)
        #expect(corePriority > awakePriority)
        #expect(awakePriority > inBedPriority)
    }
}
