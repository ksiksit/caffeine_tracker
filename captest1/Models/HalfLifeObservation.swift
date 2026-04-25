//
//  HalfLifeObservation.swift
//  captest1
//
//  베이지안 학습의 1회 관측 이력. 학습 이력 차트와 감사(audit)에 사용.
//

import Foundation
import SwiftData

@Model
final class HalfLifeObservation {
    /// 관측 대상 밤의 날짜 (그 밤이 끝나는 아침의 startOfDay).
    /// 동일 날짜 중복 학습 방지용 키.
    var date: Date
    /// 취침 시각의 예상 카페인 잔류량 (mg). prior 평균으로 계산.
    var predictedResidualAtBedtime: Double
    /// HealthKit에서 측정된 sleep onset latency (분).
    var observedSOLMinutes: Double
    /// 갱신 직전 prior 평균 (h, base half-life).
    var priorMean: Double
    /// 갱신 직전 prior 분산 (h²).
    var priorVariance: Double
    /// 갱신 후 posterior 평균 (h, base half-life).
    var posteriorMean: Double
    /// 갱신 후 posterior 분산 (h²).
    var posteriorVariance: Double
    /// 관측 시각의 condition multiplier. 학습은 base에 대해 수행되므로 감사용.
    var conditionMultiplier: Double

    /// 무효 값 저장 방지용 init 레벨 검증 에러.
    enum ValidationError: Error, Equatable {
        case nonPositiveMean(field: String, value: Double)
        case nonPositiveVariance(field: String, value: Double)
        case negativeResidual(Double)
        case invalidSOL(Double)
        case nonPositiveMultiplier(Double)
        case nonFiniteValue(field: String, value: Double)
    }

    init(
        date: Date,
        predictedResidualAtBedtime: Double,
        observedSOLMinutes: Double,
        priorMean: Double,
        priorVariance: Double,
        posteriorMean: Double,
        posteriorVariance: Double,
        conditionMultiplier: Double
    ) throws {
        try Self.validate(
            predictedResidualAtBedtime: predictedResidualAtBedtime,
            observedSOLMinutes: observedSOLMinutes,
            priorMean: priorMean,
            priorVariance: priorVariance,
            posteriorMean: posteriorMean,
            posteriorVariance: posteriorVariance,
            conditionMultiplier: conditionMultiplier
        )
        self.date = date
        self.predictedResidualAtBedtime = predictedResidualAtBedtime
        self.observedSOLMinutes = observedSOLMinutes
        self.priorMean = priorMean
        self.priorVariance = priorVariance
        self.posteriorMean = posteriorMean
        self.posteriorVariance = posteriorVariance
        self.conditionMultiplier = conditionMultiplier
    }

    private static func validate(
        predictedResidualAtBedtime: Double,
        observedSOLMinutes: Double,
        priorMean: Double,
        priorVariance: Double,
        posteriorMean: Double,
        posteriorVariance: Double,
        conditionMultiplier: Double
    ) throws {
        let finiteChecks: [(String, Double)] = [
            ("predictedResidualAtBedtime", predictedResidualAtBedtime),
            ("observedSOLMinutes", observedSOLMinutes),
            ("priorMean", priorMean),
            ("priorVariance", priorVariance),
            ("posteriorMean", posteriorMean),
            ("posteriorVariance", posteriorVariance),
            ("conditionMultiplier", conditionMultiplier)
        ]
        for (name, value) in finiteChecks where !value.isFinite {
            throw ValidationError.nonFiniteValue(field: name, value: value)
        }

        guard predictedResidualAtBedtime >= 0 else {
            throw ValidationError.negativeResidual(predictedResidualAtBedtime)
        }
        guard observedSOLMinutes >= 0 else {
            throw ValidationError.invalidSOL(observedSOLMinutes)
        }
        guard priorMean > 0 else {
            throw ValidationError.nonPositiveMean(field: "priorMean", value: priorMean)
        }
        guard posteriorMean > 0 else {
            throw ValidationError.nonPositiveMean(field: "posteriorMean", value: posteriorMean)
        }
        guard priorVariance > 0 else {
            throw ValidationError.nonPositiveVariance(field: "priorVariance", value: priorVariance)
        }
        guard posteriorVariance > 0 else {
            throw ValidationError.nonPositiveVariance(field: "posteriorVariance", value: posteriorVariance)
        }
        guard conditionMultiplier > 0 else {
            throw ValidationError.nonPositiveMultiplier(conditionMultiplier)
        }
    }
}
