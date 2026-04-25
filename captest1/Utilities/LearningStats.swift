//
//  LearningStats.swift
//  captest1
//
//  학습 대시보드용 derived 통계: SOL 예측, R², RMSE, 신뢰도, 히스토그램.
//  순수 함수 — View 의존성 없음.
//
//  ⚠️ alpha/beta 상수는 BayesianHalfLifeLearner.LikelihoodParams의 기본값과
//  반드시 동일해야 한다. 한쪽만 바뀌면 calibration 차트가 거짓말함.
//

import Foundation

enum LearningStats {

    // MARK: - Likelihood 모델 (BayesianHalfLifeLearner와 동기화 필수)
    /// SOL = α + β · residual + noise (Drake 2013 기반)
    static let alpha: Double = 15.0
    static let beta: Double = 0.10

    static func predictedSOL(residualMg: Double) -> Double {
        alpha + beta * residualMg
    }

    // MARK: - Nested types (Components가 Utilities를 참조하는 정방향 의존)

    struct Point: Identifiable {
        let id = UUID()
        let predicted: Double
        let observed: Double
        let date: Date
    }

    struct HistogramBin: Identifiable {
        let id = UUID()
        let lower: Double
        let upper: Double
        let count: Int
        var label: String { String(format: "%.0f-%.0f", lower, upper) }
    }

    // MARK: - 신뢰도 (0...1)

    /// 1 - σ_post / σ_prior_initial. σ_prior_initial = √2.25 = 1.5h 기준.
    /// posteriorVariance가 varianceFloor(0.05²)에 가까우면 ~97%.
    static func confidenceScore(posteriorVariance: Double) -> Double {
        let sigmaPost = sqrt(max(posteriorVariance, 0))
        let sigmaPriorInitial = sqrt(SettingsManager.populationPriorVariance)
        let raw = 1.0 - sigmaPost / sigmaPriorInitial
        return min(max(raw, 0), 1)
    }

    // MARK: - 정확도 지표

    /// R² 결정계수. N<3 또는 SS_tot=0이면 nil.
    static func rSquared(points: [Point]) -> Double? {
        guard points.count >= 3 else { return nil }
        let ys = points.map(\.observed)
        let mean = ys.reduce(0, +) / Double(ys.count)
        let ssTot = ys.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        guard ssTot > 0 else { return nil }
        let ssRes = points.reduce(0) {
            $0 + ($1.observed - $1.predicted) * ($1.observed - $1.predicted)
        }
        return 1 - ssRes / ssTot
    }

    /// 평균 제곱 오차의 제곱근. N=0이면 0.
    static func rmse(points: [Point]) -> Double {
        guard !points.isEmpty else { return 0 }
        let ss = points.reduce(0) {
            $0 + ($1.observed - $1.predicted) * ($1.observed - $1.predicted)
        }
        return sqrt(ss / Double(points.count))
    }

    /// 양 축 공통 도메인. 5분 패딩, 0 미만은 0. 빈 입력은 0...60.
    static func calibrationDomain(points: [Point]) -> ClosedRange<Double> {
        guard !points.isEmpty else { return 0...60 }
        let xs = points.map(\.predicted)
        let ys = points.map(\.observed)
        let lo = max(0, min(xs.min()!, ys.min()!) - 5)
        let hi = max(xs.max()!, ys.max()!) + 5
        return lo...max(hi, lo + 10)
    }

    // MARK: - 히스토그램

    /// values를 binCount개의 동일 폭 빈으로 분할.
    /// 빈 입력 → []. 모든 값이 동일 → 단일 빈 (count=N).
    /// 마지막 빈은 상한 inclusive.
    static func histogram(values: [Double], binCount: Int) -> [HistogramBin] {
        guard !values.isEmpty, binCount >= 1 else { return [] }
        let lo = values.min()!
        let hi = values.max()!
        guard hi > lo else {
            return [HistogramBin(lower: lo, upper: lo, count: values.count)]
        }
        let width = (hi - lo) / Double(binCount)
        var counts = Array(repeating: 0, count: binCount)
        for v in values {
            let idx = min(Int((v - lo) / width), binCount - 1)
            counts[idx] += 1
        }
        return (0..<binCount).map { i in
            HistogramBin(
                lower: lo + width * Double(i),
                upper: lo + width * Double(i + 1),
                count: counts[i]
            )
        }
    }
}
