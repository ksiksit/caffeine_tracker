//
//  BayesianHalfLifeLearnerTests.swift
//  captest1Tests
//
//  정규-정규 켤레(선형화) 모델의 closed-form 검증,
//  skip 게이트, clamp, 슬라이더 reset 단위 테스트.
//

import Foundation
import SwiftData
import Testing
@testable import captest1

@MainActor
struct BayesianHalfLifeLearnerTests {

    // MARK: - 테스트 환경 헬퍼

    private func makeContext() throws -> ModelContext {
        let schema = Schema([CaffeineRecord.self, HalfLifeObservation.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func freshSettings(halfLife: Double = 5.0,
                               isLearningEnabled: Bool = true,
                               conditionRaw: Int = 0) -> SettingsManager {
        // 테스트 간 UserDefaults 오염 방지: 전역 suite 대신 ephemeral suite 사용은
        // SettingsManager 구조상 어려우므로 값을 명시적으로 설정.
        let s = SettingsManager()
        s.halfLife = halfLife  // didSet이 learnedMean도 동일하게 리셋
        s.learnedHalfLifeVariance = SettingsManager.populationPriorVariance
        s.isLearningEnabled = isLearningEnabled
        s.conditionRawValue = conditionRaw
        s.lastLearnedDate = nil
        return s
    }

    /// 지정된 날(23시가 inBed, 23:30에 asleepCore) 요약.
    private func summary(bedtime: Date, sleepDurationHours: Double,
                         solMinutes: Double) -> SleepSummary {
        let asleepStart = bedtime.addingTimeInterval(solMinutes * 60)
        let asleepEnd = asleepStart.addingTimeInterval(sleepDurationHours * 3600)
        return SleepSummary(date: asleepEnd, records: [
            SleepRecord(startDate: bedtime, endDate: asleepStart, stage: .inBed),
            SleepRecord(startDate: asleepStart, endDate: asleepEnd, stage: .asleepCore)
        ])
    }

    private func record(amount: Int, at date: Date) -> CaffeineRecord {
        CaffeineRecord(amount: amount, drinkName: "커피", timestamp: date)
    }

    private func observations(in context: ModelContext) throws -> [HalfLifeObservation] {
        try context.fetch(FetchDescriptor<HalfLifeObservation>())
            .sorted { $0.date < $1.date }
    }

    // MARK: - skip 게이트

    @Test func skipsWhenLearningDisabled() throws {
        let ctx = try makeContext()
        let s = freshSettings(isLearningEnabled: false)
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 30),
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )
        #expect(result == nil)
    }

    @Test func skipsWhenNoSummary() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let result = learner.updateIfNewObservation(
            yesterdaySummary: nil,
            allCaffeineRecords: []
        )
        #expect(result == nil)
    }

    @Test func skipsWhenSleepTooShort() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 2, solMinutes: 20),
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )
        #expect(result == nil)
    }

    @Test func skipsWhenInBedMissing() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let now = Date()
        let summaryNoInBed = SleepSummary(date: now.addingTimeInterval(8 * 3600), records: [
            SleepRecord(startDate: now, endDate: now.addingTimeInterval(8 * 3600),
                        stage: .asleepCore)
        ])
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summaryNoInBed,
            allCaffeineRecords: [record(amount: 200, at: now.addingTimeInterval(-4 * 3600))]
        )
        #expect(result == nil)
    }

    @Test func skipsWhenSOLTooLarge() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 240),
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )
        #expect(result == nil)
    }

    @Test func skipsWhenResidualTooSmall() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        // 카페인 0건 → 잔량 0 → skip
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 15),
            allCaffeineRecords: []
        )
        #expect(result == nil)
    }

    @Test func batchReportsNoSleepSummaryReason() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)

        let result = learner.updateMissingObservations(
            summaries: [],
            allCaffeineRecords: []
        )

        #expect(result.updated.isEmpty)
        #expect(result.displayReason == .noSleepSummary)
    }

    @Test func batchReportsSleepTooShortReason() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()

        let result = learner.updateMissingObservations(
            summaries: [summary(bedtime: bedtime, sleepDurationHours: 2, solMinutes: 20)],
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )

        #expect(result.updated.isEmpty)
        #expect(result.displayReason == .sleepTooShort)
    }

    @Test func batchReportsMissingBedtimeReason() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let summaryNoInBed = SleepSummary(date: bedtime.addingTimeInterval(8 * 3600), records: [
            SleepRecord(startDate: bedtime, endDate: bedtime.addingTimeInterval(8 * 3600),
                        stage: .asleepCore)
        ])

        let result = learner.updateMissingObservations(
            summaries: [summaryNoInBed],
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )

        #expect(result.updated.isEmpty)
        #expect(result.displayReason == .missingBedtime)
    }

    @Test func batchReportsInsufficientCaffeineResidualReason() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()

        let result = learner.updateMissingObservations(
            summaries: [summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 15)],
            allCaffeineRecords: []
        )

        #expect(result.updated.isEmpty)
        #expect(result.displayReason == .insufficientCaffeineResidual)
    }

    @Test func skipsOnDuplicateSameDay() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let sum = summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 30)
        let records = [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        let first = learner.updateIfNewObservation(
            yesterdaySummary: sum, allCaffeineRecords: records
        )
        #expect(first != nil)
        let second = learner.updateIfNewObservation(
            yesterdaySummary: sum, allCaffeineRecords: records
        )
        #expect(second == nil)
    }

    @Test func batchUpdatesMissingObservationsOldestFirst() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let calendar = Calendar(identifier: .gregorian)
        let oldBedtime = calendar.date(
            from: DateComponents(year: 2026, month: 4, day: 20, hour: 23)
        )!
        let newBedtime = calendar.date(
            from: DateComponents(year: 2026, month: 4, day: 21, hour: 23)
        )!
        let oldSummary = summary(bedtime: oldBedtime, sleepDurationHours: 8, solMinutes: 30)
        let newSummary = summary(bedtime: newBedtime, sleepDurationHours: 8, solMinutes: 40)

        let result = learner.updateMissingObservations(
            summaries: [newSummary, oldSummary],
            allCaffeineRecords: [
                record(amount: 200, at: oldBedtime.addingTimeInterval(-4 * 3600)),
                record(amount: 200, at: newBedtime.addingTimeInterval(-4 * 3600))
            ]
        )

        let saved = try observations(in: ctx)
        #expect(result.updated.count == 2)
        #expect(result.displayReason == nil)
        #expect(saved.count == 2)
        #expect(saved[0].date < saved[1].date)
        #expect(abs(saved[1].priorMean - saved[0].posteriorMean) < 1e-9)
    }

    @Test func batchSkipsAlreadyLearnedDays() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let sum = summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 30)
        let records = [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]

        let first = learner.updateMissingObservations(
            summaries: [sum], allCaffeineRecords: records
        )
        let second = learner.updateMissingObservations(
            summaries: [sum], allCaffeineRecords: records
        )

        #expect(first.updated.count == 1)
        #expect(second.updated.isEmpty)
        #expect(second.displayReason == .alreadyLearned)
        #expect(try observations(in: ctx).count == 1)
    }

    // MARK: - 갱신 동작

    @Test func updatesReducesVariance() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let initialVar = s.learnedHalfLifeVariance
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 30),
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )
        #expect(result != nil)
        #expect(s.learnedHalfLifeVariance < initialVar)
    }

    @Test func posteriorClampedToValidRange() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        // 극단값: 500mg 잔량 + SOL 120분 → posterior가 위로 튀려 해도 trust region과 clamp로 방어
        let result = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 120),
            allCaffeineRecords: [record(amount: 500, at: bedtime.addingTimeInterval(-1 * 3600))]
        )
        #expect(result != nil)
        #expect(s.learnedHalfLifeMean >= BayesianHalfLifeLearner.clampMin)
        #expect(s.learnedHalfLifeMean <= BayesianHalfLifeLearner.clampMax)
    }

    @Test func trustRegionLimitsSingleStep() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        let priorBefore = s.learnedHalfLifeMean
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        _ = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 150),
            allCaffeineRecords: [record(amount: 400, at: bedtime.addingTimeInterval(-1 * 3600))]
        )
        let step = abs(s.learnedHalfLifeMean - priorBefore)
        #expect(step <= BayesianHalfLifeLearner.maxStepPerUpdate + 1e-9)
    }

    @Test func varianceFloorApplied() throws {
        let ctx = try makeContext()
        let s = freshSettings()
        s.learnedHalfLifeVariance = 0.001  // 이미 매우 작은 사전분산
        let learner = BayesianHalfLifeLearner(settings: s, context: ctx)
        let bedtime = Date()
        _ = learner.updateIfNewObservation(
            yesterdaySummary: summary(bedtime: bedtime, sleepDurationHours: 8, solMinutes: 25),
            allCaffeineRecords: [record(amount: 200, at: bedtime.addingTimeInterval(-4 * 3600))]
        )
        #expect(s.learnedHalfLifeVariance >= BayesianHalfLifeLearner.varianceFloor - 1e-12)
    }

    // MARK: - 슬라이더 reset

    @Test func sliderChangeResetsLearningState() throws {
        let s = freshSettings()
        s.learnedHalfLifeMean = 6.3  // 학습으로 갱신된 상태 가정
        s.learnedHalfLifeVariance = 0.4
        s.lastLearnedDate = Date()

        // 사용자가 슬라이더를 4.0h로 조작
        s.halfLife = 4.0

        #expect(s.learnedHalfLifeMean == 4.0)
        #expect(s.learnedHalfLifeVariance == SettingsManager.populationPriorVariance)
        #expect(s.lastLearnedDate == nil)
    }

    @Test func inferredBaseHalfLifeRespectsLearningToggle() throws {
        let s = freshSettings()
        s.learnedHalfLifeMean = 6.3
        // 학습 ON → 학습값 사용
        s.isLearningEnabled = true
        #expect(s.inferredBaseHalfLife == 6.3)
        // 학습 OFF → 슬라이더값 사용
        s.isLearningEnabled = false
        #expect(s.inferredBaseHalfLife == s.halfLife)
    }
}
