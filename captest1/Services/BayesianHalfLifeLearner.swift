//
//  BayesianHalfLifeLearner.swift
//  captest1
//
//  수면 잠복기(SOL) 관측을 바탕으로 카페인 base 반감기를
//  정규-정규 켤레 (선형화) 모델로 베이지안 갱신한다.
//
//  학술 근거:
//  - Kovar et al. 2021 (PMC8302243): demographic-informed PBPK personalization
//  - Ramakrishnan & Reifman 2016 (PMC5020365): caffeine PK + sleep 통합 모델
//  - Koletzko 2021: 모집단 평균 5h, σ ≈ 1.5h
//  - Drake et al. 2013: 취침 전 카페인 잔량 vs SOL 증가 관계
//

import Foundation
import SwiftData

enum LearningSkipReason: Equatable {
    case learningDisabled
    case noSleepSummary
    case sleepTooShort
    case missingBedtime
    case invalidSOL
    case alreadyLearned
    case invalidPrior
    case insufficientCaffeineResidual
    case invalidObservation

    var message: String {
        switch self {
        case .learningDisabled:
            "자동 학습이 꺼져 있어요."
        case .noSleepSummary:
            "최근 수면 기록을 찾지 못했어요."
        case .sleepTooShort:
            "최근 수면 시간이 4시간보다 짧아 학습하지 않았어요."
        case .missingBedtime:
            "취침 시작 시각을 찾지 못해 SOL을 계산할 수 없어요."
        case .invalidSOL:
            "수면 잠복기 값이 유효 범위를 벗어났어요."
        case .alreadyLearned:
            "최근 수면 기록은 이미 학습에 반영됐어요."
        case .invalidPrior:
            "현재 반감기 설정값이 유효하지 않아 학습하지 않았어요."
        case .insufficientCaffeineResidual:
            "취침 시 카페인 잔량이 너무 적어 학습할 정보가 부족했어요."
        case .invalidObservation:
            "학습 관측값을 저장할 수 없어 건너뛰었어요."
        }
    }
}

struct LearningBatchResult {
    let updated: [BayesianHalfLifeLearner.UpdateResult]
    let displayReason: LearningSkipReason?
}

@MainActor
struct BayesianHalfLifeLearner {

    /// likelihood 모델 파라미터. 모집단 평균값(논문 근거)으로 초기화.
    struct LikelihoodParams {
        /// 카페인 0mg일 때 평균 SOL (분). Drake 2013 control.
        var alpha: Double = 15.0
        /// 단위 mg당 SOL 증가량 (분/mg). 초기값 0.10, 민감도 분석 범위 0.05~0.20.
        var beta: Double = 0.10
        /// SOL 관측 노이즈 표준편차 (분). HealthKit 단계 분류 + 의식적 추정 오차.
        var sigmaObs: Double = 10.0

        nonisolated init(
            alpha: Double = 15.0,
            beta: Double = 0.10,
            sigmaObs: Double = 10.0
        ) {
            self.alpha = alpha
            self.beta = beta
            self.sigmaObs = sigmaObs
        }
    }

    /// 1회 갱신 결과. 영속화는 호출자가 수행.
    struct UpdateResult {
        let observation: HalfLifeObservation
        let posteriorMean: Double
        let posteriorVariance: Double
    }

    static let clampMin: Double = AppConstants.Pharmacokinetics.minHalfLifeHours
    static let clampMax: Double = AppConstants.Pharmacokinetics.maxHalfLifeHours
    /// linearization trust region (h). 1회 갱신당 변화량 상한.
    static let maxStepPerUpdate: Double = 0.5
    /// 분산 floor (h²). 0이 되어 새 정보 수용을 멈추는 것 방지.
    static let varianceFloor: Double = 0.05 * 0.05
    /// 학습 doses 룩백 윈도우 (시간). 24h 이전은 잔량 ~0.
    static let dosesLookbackHours: Double = 24
    /// 학습 skip 임계값 (mg). 잔량이 너무 작으면 정보량 0이라 skip.
    static let minResidualForLearning: Double = 1.0
    /// SOL 이상치 상한 (분).
    static let maxAcceptableSOLMinutes: Double = 180
    /// 학습 가능한 최소 수면 시간 (초).
    static let minSleepDurationSeconds: TimeInterval = 4 * 3600

    private let settings: SettingsManager
    private let context: ModelContext
    private let params: LikelihoodParams

    init(
        settings: SettingsManager,
        context: ModelContext,
        params: LikelihoodParams = LikelihoodParams()
    ) {
        self.settings = settings
        self.context = context
        self.params = params
    }

    // MARK: - Public 진입점

    /// 어제(또는 학습되지 않은 가장 최근) SOL이 있다면 1회 갱신.
    /// - Returns: 갱신 결과 (skip된 경우 nil).
    @discardableResult
    func updateIfNewObservation(
        yesterdaySummary: SleepSummary?,
        allCaffeineRecords: [CaffeineRecord]
    ) -> UpdateResult? {
        guard let summary = yesterdaySummary else { return nil }
        return update(summary: summary, allCaffeineRecords: allCaffeineRecords).result
    }

    /// 최근 수면 요약 중 아직 학습되지 않은 날짜를 오래된 순서로 모두 갱신.
    func updateMissingObservations(
        summaries: [SleepSummary],
        allCaffeineRecords: [CaffeineRecord]
    ) -> LearningBatchResult {
        guard settings.isLearningEnabled else {
            return LearningBatchResult(updated: [], displayReason: .learningDisabled)
        }
        guard !summaries.isEmpty else {
            return LearningBatchResult(updated: [], displayReason: .noSleepSummary)
        }

        let sortedSummaries = summaries.sorted { $0.date < $1.date }
        var seenDayKeys = Set<Date>()
        var updated: [UpdateResult] = []
        var latestReason: (date: Date, reason: LearningSkipReason)?

        for summary in sortedSummaries {
            let dayKey = Calendar.current.startOfDay(for: summary.date)
            guard seenDayKeys.insert(dayKey).inserted else { continue }
            guard !hasExistingObservation(on: dayKey) else {
                latestReason = (summary.date, .alreadyLearned)
                continue
            }

            let attempt = update(summary: summary, allCaffeineRecords: allCaffeineRecords)
            if let result = attempt.result {
                updated.append(result)
            } else if let reason = attempt.reason,
                      latestReason == nil || summary.date >= latestReason!.date {
                latestReason = (summary.date, reason)
            }
        }

        return LearningBatchResult(
            updated: updated,
            displayReason: updated.isEmpty ? latestReason?.reason : nil
        )
    }

    // MARK: - 헬퍼 (게이트 / 쿼리 / 계산 / 영속화)

    private func update(
        summary: SleepSummary,
        allCaffeineRecords: [CaffeineRecord]
    ) -> (result: UpdateResult?, reason: LearningSkipReason?) {
        guard settings.isLearningEnabled else { return (nil, .learningDisabled) }
        guard let gated = extractBedtime(from: summary) else {
            return (nil, skipReasonForInvalidSummary(summary))
        }

        let dayKey = Calendar.current.startOfDay(for: summary.date)
        guard !hasExistingObservation(on: dayKey) else {
            return (nil, .alreadyLearned)
        }

        let doses = dosesInLearningWindow(
            bedtime: gated.bedtime, records: allCaffeineRecords
        )

        let priorMean = settings.learnedHalfLifeMean
        let priorVar = settings.learnedHalfLifeVariance
        let multiplier = settings.condition.multiplier
        guard priorMean > 0, priorVar > 0, multiplier > 0 else {
            return (nil, .invalidPrior)
        }

        guard let lin = linearize(
            bedtime: gated.bedtime, doses: doses,
            priorMean: priorMean, multiplier: multiplier
        ) else { return (nil, .insufficientCaffeineResidual) }

        let raw = posteriorEstimate(
            priorMean: priorMean, priorVariance: priorVar,
            linearization: lin, solMinutes: gated.solMinutes
        )
        let safe = applySafetyBounds(
            rawMean: raw.mean, rawVariance: raw.variance, priorMean: priorMean
        )

        // E1a: 모델이 무효 값을 거부하면 skip.
        guard let obs = try? HalfLifeObservation(
            date: dayKey,
            predictedResidualAtBedtime: lin.cMu,
            observedSOLMinutes: gated.solMinutes,
            priorMean: priorMean,
            priorVariance: priorVar,
            posteriorMean: safe.mean,
            posteriorVariance: safe.variance,
            conditionMultiplier: multiplier
        ) else { return (nil, .invalidObservation) }

        persist(observation: obs, postMean: safe.mean, postVar: safe.variance, dayKey: dayKey)
        let result = UpdateResult(
            observation: obs, posteriorMean: safe.mean, posteriorVariance: safe.variance
        )
        return (result, nil)
    }

    /// summary의 유효성을 검증하고 bedtime + SOL(분)을 추출.
    private func extractBedtime(
        from summary: SleepSummary
    ) -> (bedtime: Date, solMinutes: Double)? {
        guard summary.totalSleepDuration >= Self.minSleepDurationSeconds else { return nil }
        guard let solSeconds = summary.sleepOnsetLatency,
              solSeconds.isFinite, solSeconds >= 0
        else { return nil }
        let solMinutes = solSeconds / 60
        guard solMinutes <= Self.maxAcceptableSOLMinutes else { return nil }
        guard let bedtime = summary.bedtimeStart ?? summary.records
            .filter({ $0.stage == .inBed })
            .map(\.startDate)
            .min()
        else { return nil }
        return (bedtime, solMinutes)
    }

    private func skipReasonForInvalidSummary(_ summary: SleepSummary) -> LearningSkipReason {
        guard summary.totalSleepDuration >= Self.minSleepDurationSeconds else {
            return .sleepTooShort
        }
        guard let solSeconds = summary.sleepOnsetLatency else {
            return .missingBedtime
        }
        guard solSeconds.isFinite, solSeconds >= 0,
              solSeconds / 60 <= Self.maxAcceptableSOLMinutes
        else { return .invalidSOL }
        guard summary.bedtimeStart != nil || summary.records.contains(where: { $0.stage == .inBed }) else {
            return .missingBedtime
        }
        return .invalidSOL
    }

    /// 같은 날짜의 학습 이력이 이미 존재하는지 확인 (날짜 범위 쿼리로 정밀도 이슈 회피).
    private func hasExistingObservation(on dayKey: Date) -> Bool {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayKey)
        else { return true }  // 날짜 계산 실패 시 안전하게 skip
        let predicate = #Predicate<HalfLifeObservation> {
            $0.date >= dayKey && $0.date < nextDay
        }
        let descriptor = FetchDescriptor<HalfLifeObservation>(predicate: predicate)
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// [bedtime - dosesLookbackHours, bedtime] 윈도우의 dose 목록.
    private func dosesInLearningWindow(
        bedtime: Date, records: [CaffeineRecord]
    ) -> [CaffeineKineticsCalculator.Dose] {
        let lookbackStart = bedtime.addingTimeInterval(-Self.dosesLookbackHours * 3600)
        return records
            .filter { $0.timestamp >= lookbackStart && $0.timestamp <= bedtime }
            .map { CaffeineKineticsCalculator.Dose(
                timestamp: $0.timestamp, amountMg: Double($0.amount)
            )}
    }

    /// prior 평균 주변에서의 C(μ), C'(μ)를 계산.
    /// 잔량 C(μ)가 학습 임계값 미만이면 정보량 부족으로 nil.
    private struct Linearization {
        let cMu: Double
        let cPrime: Double
    }
    private func linearize(
        bedtime: Date,
        doses: [CaffeineKineticsCalculator.Dose],
        priorMean: Double,
        multiplier: Double
    ) -> Linearization? {
        let effectiveMu = priorMean * multiplier
        let cMu = CaffeineKineticsCalculator.totalRemaining(
            at: bedtime, doses: doses, halfLifeHours: effectiveMu
        )
        guard cMu >= Self.minResidualForLearning else { return nil }
        let cPrime = derivativeAtBedtime(
            doses: doses, bedtime: bedtime, baseMu: priorMean, multiplier: multiplier
        )
        return Linearization(cMu: cMu, cPrime: cPrime)
    }

    /// 정규-정규 켤레(선형화) 갱신. trust region/clamp 이전의 raw posterior를 반환.
    private func posteriorEstimate(
        priorMean: Double,
        priorVariance: Double,
        linearization: Linearization,
        solMinutes: Double
    ) -> (mean: Double, variance: Double) {
        let aTilde = params.beta * linearization.cPrime
        let yTilde = solMinutes - params.alpha
            - params.beta * (linearization.cMu - linearization.cPrime * priorMean)
        let priorPrec = 1.0 / priorVariance
        let obsPrec = (aTilde * aTilde) / (params.sigmaObs * params.sigmaObs)
        let postPrec = priorPrec + obsPrec
        let rawPostVar = 1.0 / postPrec
        let rawPostMean = rawPostVar * (
            priorMean / priorVariance
            + (aTilde * yTilde) / (params.sigmaObs * params.sigmaObs)
        )
        return (rawPostMean, rawPostVar)
    }

    /// trust region → clamp → variance floor 순으로 안전장치 적용.
    private func applySafetyBounds(
        rawMean: Double, rawVariance: Double, priorMean: Double
    ) -> (mean: Double, variance: Double) {
        let stepLimited = max(
            min(rawMean, priorMean + Self.maxStepPerUpdate),
            priorMean - Self.maxStepPerUpdate
        )
        let clamped = max(min(stepLimited, Self.clampMax), Self.clampMin)
        let flooredVar = max(rawVariance, Self.varianceFloor)
        return (clamped, flooredVar)
    }

    /// 학습 결과를 SwiftData와 설정에 반영.
    private func persist(
        observation: HalfLifeObservation,
        postMean: Double,
        postVar: Double,
        dayKey: Date
    ) {
        context.insert(observation)
        settings.learnedHalfLifeMean = postMean
        settings.learnedHalfLifeVariance = postVar
        settings.lastLearnedDate = dayKey
        try? context.save()
    }

    /// ∂C/∂μ_base (μ_base는 시간 단위 base half-life).
    /// C = Σⱼ doseⱼ · exp(-ln2/(μ_base·m) · Δtⱼ)
    /// dC/dμ_base = Σⱼ doseⱼ · exp(...) · (ln2 · Δtⱼ) / (m · μ_base²)
    private func derivativeAtBedtime(
        doses: [CaffeineKineticsCalculator.Dose],
        bedtime: Date,
        baseMu: Double,
        multiplier: Double
    ) -> Double {
        let effectiveMu = baseMu * multiplier
        guard effectiveMu > 0, baseMu > 0, multiplier > 0 else { return 0 }
        let ke = log(2) / effectiveMu
        var sum = 0.0
        for dose in doses {
            let dtHours = bedtime.timeIntervalSince(dose.timestamp) / 3600
            guard dtHours >= 0 else { continue }
            let exponent = exp(-ke * dtHours)
            sum += dose.amountMg * exponent * (log(2) * dtHours) / (multiplier * baseMu * baseMu)
        }
        return sum
    }
}
