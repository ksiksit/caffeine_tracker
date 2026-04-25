//
//  SleepDataSOLTests.swift
//  captest1Tests
//
//  SleepSummary.sleepOnsetLatency 단위 테스트.
//

import Foundation
import Testing
@testable import captest1

struct SleepDataSOLTests {

    /// 모든 record가 동일한 baseline을 공유하도록 instance-level로 고정.
    /// 임의의 절대 시각이며 22:00 가상 기준점.
    private let baseline: Date = Date(timeIntervalSince1970: 1_800_000_000)

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        let offsetMinutes: Int
        if hour >= 22 {
            offsetMinutes = (hour - 22) * 60 + minute
        } else {
            offsetMinutes = (hour + 2) * 60 + minute  // 다음날
        }
        return baseline.addingTimeInterval(Double(offsetMinutes) * 60)
    }

    private func record(_ stage: SleepStage, _ startHour: Int, _ startMinute: Int,
                        _ endHour: Int, _ endMinute: Int) -> SleepRecord {
        SleepRecord(
            startDate: date(startHour, startMinute),
            endDate: date(endHour, endMinute),
            stage: stage
        )
    }

    private func summary(_ records: [SleepRecord]) -> SleepSummary {
        SleepSummary(date: Date(), records: records)
    }

    // MARK: - 정상 케이스

    @Test func normalSequence_inBedThenCore_returns30min() {
        let s = summary([
            record(.inBed, 22, 0, 22, 30),
            record(.asleepCore, 22, 30, 23, 30),
            record(.asleepDeep, 23, 30, 1, 0)
        ])
        #expect(s.sleepOnsetLatency == Double(30 * 60))
    }

    @Test func longLatency_45min() {
        let s = summary([
            record(.inBed, 23, 0, 23, 45),
            record(.asleepCore, 23, 45, 2, 0)
        ])
        #expect(s.sleepOnsetLatency == Double(45 * 60))
    }

    @Test func zeroLatency_inBedAndAsleepStartTogether() {
        let s = summary([
            record(.inBed, 22, 0, 22, 0),
            record(.asleepREM, 22, 0, 5, 0)
        ])
        #expect(s.sleepOnsetLatency == 0)
    }

    @Test func bedtimeStartFallback_noMergedInBed_returns30min() {
        let s = SleepSummary(
            date: Date(),
            records: [
                record(.asleepCore, 22, 30, 23, 30),
                record(.asleepDeep, 23, 30, 1, 0)
            ],
            bedtimeStart: date(22, 0)
        )
        #expect(s.sleepOnsetLatency == Double(30 * 60))
    }

    // MARK: - skip / nil 케이스

    @Test func noInBed_returnsNil() {
        let s = summary([
            record(.asleepCore, 22, 30, 23, 30),
            record(.asleepDeep, 23, 30, 1, 0)
        ])
        #expect(s.sleepOnsetLatency == nil)
    }

    @Test func onlyInBed_noAsleep_returnsNil() {
        let s = summary([
            record(.inBed, 22, 0, 23, 0),
            record(.awake, 23, 0, 23, 30)
        ])
        #expect(s.sleepOnsetLatency == nil)
    }

    @Test func emptyRecords_returnsNil() {
        let s = summary([])
        #expect(s.sleepOnsetLatency == nil)
    }

    // MARK: - 엣지 케이스

    @Test func multipleInBed_usesEarliestStart() {
        let s = summary([
            record(.inBed, 23, 0, 23, 15),
            record(.inBed, 22, 0, 22, 30),  // 더 이른 inBed
            record(.asleepCore, 23, 0, 4, 0)
        ])
        // 22:00 inBed → 23:00 asleep = 60분
        #expect(s.sleepOnsetLatency == Double(60 * 60))
    }

    @Test func multipleAsleepStages_usesEarliestAsleepStart() {
        let s = summary([
            record(.inBed, 22, 0, 22, 20),
            record(.asleepREM, 23, 0, 23, 30),  // 늦은 asleep
            record(.asleepCore, 22, 20, 23, 0)  // 더 이른 asleep
        ])
        // 22:00 inBed → 22:20 asleep = 20분
        #expect(s.sleepOnsetLatency == Double(20 * 60))
    }

    @Test func asleepBeforeInBed_negativeLatency_returnsNil() {
        // 데이터 이상: asleep 시작이 inBed 시작보다 빠름
        let s = summary([
            record(.asleepCore, 22, 0, 23, 0),
            record(.inBed, 22, 30, 22, 45)
        ])
        #expect(s.sleepOnsetLatency == nil)
    }

    @Test func awakeStageNotCountedAsAsleep() {
        // awake는 asleep으로 간주되지 않음
        let s = summary([
            record(.inBed, 22, 0, 22, 30),
            record(.awake, 22, 30, 23, 0),
            record(.asleepCore, 23, 0, 5, 0)
        ])
        // 22:00 inBed → 23:00 asleep = 60분
        #expect(s.sleepOnsetLatency == Double(60 * 60))
    }

    @Test func unspecifiedAsleepCounted() {
        let s = summary([
            record(.inBed, 22, 0, 22, 10),
            record(.asleepUnspecified, 22, 10, 5, 0)
        ])
        #expect(s.sleepOnsetLatency == Double(10 * 60))
    }
}
