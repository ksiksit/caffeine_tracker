//
//  LearningStatsTests.swift
//  captest1Tests
//
//  순수 통계 함수 검증.
//

import Foundation
import Testing
@testable import captest1

struct LearningStatsTests {

    private func point(predicted: Double, observed: Double) -> LearningStats.Point {
        LearningStats.Point(
            predicted: predicted, observed: observed, date: Date()
        )
    }

    // MARK: - predictedSOL

    @Test func predictedSOL_zeroResidual_returnsAlpha() {
        #expect(LearningStats.predictedSOL(residualMg: 0) == 15.0)
    }

    @Test func predictedSOL_hundredMg_returns25() {
        #expect(LearningStats.predictedSOL(residualMg: 100) == 25.0)
    }

    // MARK: - confidenceScore

    @Test func confidenceScore_priorVariance_returnsZero() {
        let score = LearningStats.confidenceScore(
            posteriorVariance: SettingsManager.populationPriorVariance
        )
        #expect(abs(score) < 1e-9)
    }

    @Test func confidenceScore_zeroVariance_returnsOne() {
        #expect(LearningStats.confidenceScore(posteriorVariance: 0) == 1.0)
    }

    @Test func confidenceScore_largerThanPrior_clampsToZero() {
        let score = LearningStats.confidenceScore(posteriorVariance: 100)
        #expect(score == 0)
    }

    @Test func confidenceScore_negativeVariance_clampsToOne() {
        // 방어적: 음수 분산은 sqrt 보호 후 0 → score = 1
        #expect(LearningStats.confidenceScore(posteriorVariance: -1) == 1.0)
    }

    @Test func confidenceScore_atFloor_isHighlyConfident() {
        // varianceFloor = 0.05² = 0.0025 → σ_post = 0.05
        // 1 - 0.05/1.5 ≈ 0.967
        let score = LearningStats.confidenceScore(posteriorVariance: 0.0025)
        #expect(abs(score - (1 - 0.05 / 1.5)) < 1e-9)
        #expect(score > 0.96 && score < 0.97)
    }

    // MARK: - rSquared

    @Test func rSquared_perfectFit_returnsOne() {
        let pts = [
            point(predicted: 10, observed: 10),
            point(predicted: 20, observed: 20),
            point(predicted: 30, observed: 30)
        ]
        let r2 = LearningStats.rSquared(points: pts)
        #expect(r2 != nil)
        #expect(abs(r2! - 1.0) < 1e-9)
    }

    @Test func rSquared_meanBaseline_returnsZero() {
        // predicted = mean(observed) → SS_res = SS_tot → R² = 0
        let observed = [10.0, 20.0, 30.0]
        let mean = 20.0
        let pts = observed.map { point(predicted: mean, observed: $0) }
        let r2 = LearningStats.rSquared(points: pts)
        #expect(r2 != nil)
        #expect(abs(r2!) < 1e-9)
    }

    @Test func rSquared_worseThanMean_returnsNegative() {
        let pts = [
            point(predicted: 30, observed: 10),
            point(predicted: 10, observed: 20),
            point(predicted: 50, observed: 30)
        ]
        let r2 = LearningStats.rSquared(points: pts)
        #expect(r2 != nil && r2! < 0)
    }

    @Test func rSquared_lessThanThreePoints_returnsNil() {
        let pts = [point(predicted: 10, observed: 10),
                   point(predicted: 20, observed: 20)]
        #expect(LearningStats.rSquared(points: pts) == nil)
    }

    @Test func rSquared_emptyPoints_returnsNil() {
        #expect(LearningStats.rSquared(points: []) == nil)
    }

    @Test func rSquared_zeroVariance_returnsNil() {
        // 모든 observed가 동일 → SS_tot = 0
        let pts = [
            point(predicted: 10, observed: 20),
            point(predicted: 30, observed: 20),
            point(predicted: 50, observed: 20)
        ]
        #expect(LearningStats.rSquared(points: pts) == nil)
    }

    // MARK: - rmse

    @Test func rmse_perfectFit_returnsZero() {
        let pts = [
            point(predicted: 1, observed: 1),
            point(predicted: 2, observed: 2),
            point(predicted: 3, observed: 3)
        ]
        #expect(LearningStats.rmse(points: pts) == 0)
    }

    @Test func rmse_knownErrors() {
        // residuals: 3, 4, 0 → mean(SS) = (9+16+0)/3 = 25/3 → sqrt ≈ 2.887
        let pts = [
            point(predicted: 0, observed: 3),
            point(predicted: 0, observed: 4),
            point(predicted: 5, observed: 5)
        ]
        let r = LearningStats.rmse(points: pts)
        #expect(abs(r - sqrt(25.0 / 3.0)) < 1e-9)
    }

    @Test func rmse_emptyPoints_returnsZero() {
        #expect(LearningStats.rmse(points: []) == 0)
    }

    // MARK: - calibrationDomain

    @Test func calibrationDomain_emptyPoints_returnsDefault() {
        let d = LearningStats.calibrationDomain(points: [])
        #expect(d == 0...60)
    }

    @Test func calibrationDomain_paddingApplied() {
        let pts = [
            point(predicted: 20, observed: 30),
            point(predicted: 40, observed: 50)
        ]
        let d = LearningStats.calibrationDomain(points: pts)
        // min(20,30) - 5 = 15, max(40,50) + 5 = 55
        #expect(d.lowerBound == 15)
        #expect(d.upperBound == 55)
    }

    @Test func calibrationDomain_clampsLowerToZero() {
        let pts = [point(predicted: 2, observed: 1)]
        let d = LearningStats.calibrationDomain(points: pts)
        // min(1,2) - 5 = -4 → clamp to 0
        #expect(d.lowerBound == 0)
    }

    // MARK: - histogram

    @Test func histogram_emptyValues_returnsEmpty() {
        #expect(LearningStats.histogram(values: [], binCount: 5).isEmpty)
    }

    @Test func histogram_zeroBinCount_returnsEmpty() {
        #expect(LearningStats.histogram(values: [1, 2, 3], binCount: 0).isEmpty)
    }

    @Test func histogram_allSameValues_returnsSingleBin() {
        let bins = LearningStats.histogram(values: [5, 5, 5, 5], binCount: 3)
        #expect(bins.count == 1)
        #expect(bins[0].count == 4)
        #expect(bins[0].lower == 5 && bins[0].upper == 5)
    }

    @Test func histogram_uniformDistribution_evenBins() {
        // 0~50 범위, 5등분 (각 폭 10): 0, 10, 20, 30, 40 → 각 빈 1개
        let bins = LearningStats.histogram(
            values: [0, 10, 20, 30, 40], binCount: 5
        )
        #expect(bins.count == 5)
        for bin in bins {
            #expect(bin.count == 1)
        }
    }

    @Test func histogram_maxValueGoesIntoLastBin() {
        // 최대값이 마지막 빈 상한 inclusive
        let bins = LearningStats.histogram(values: [0, 5, 10], binCount: 2)
        // 폭 5, 빈: [0,5), [5,10] (마지막 inclusive)
        #expect(bins.count == 2)
        // 0 → bin0, 5 → bin1, 10 → bin1
        #expect(bins[0].count == 1)
        #expect(bins[1].count == 2)
    }

    @Test func histogram_totalCountPreserved() {
        let values: [Double] = [1, 3, 5, 7, 9, 11, 13, 15]
        let bins = LearningStats.histogram(values: values, binCount: 4)
        let total = bins.reduce(0) { $0 + $1.count }
        #expect(total == values.count)
    }
}
