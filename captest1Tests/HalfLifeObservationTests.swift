//
//  HalfLifeObservationTests.swift
//  captest1Tests
//
//  HalfLifeObservation 생성자 값 검증(무효값 거부) 테스트.
//

import Foundation
import Testing
@testable import captest1

@MainActor
struct HalfLifeObservationTests {

    /// 모든 필드가 유효한 기본 인수. 개별 테스트에서 필요한 필드만 오버라이드.
    private func make(
        date: Date = Date(),
        predictedResidualAtBedtime: Double = 50,
        observedSOLMinutes: Double = 20,
        priorMean: Double = 5.0,
        priorVariance: Double = 1.5,
        posteriorMean: Double = 5.1,
        posteriorVariance: Double = 1.3,
        conditionMultiplier: Double = 1.0
    ) throws -> HalfLifeObservation {
        try HalfLifeObservation(
            date: date,
            predictedResidualAtBedtime: predictedResidualAtBedtime,
            observedSOLMinutes: observedSOLMinutes,
            priorMean: priorMean,
            priorVariance: priorVariance,
            posteriorMean: posteriorMean,
            posteriorVariance: posteriorVariance,
            conditionMultiplier: conditionMultiplier
        )
    }

    // MARK: - 정상 케이스

    @Test func validArgsSucceed() throws {
        let obs = try make()
        #expect(obs.priorMean == 5.0)
        #expect(obs.posteriorMean == 5.1)
    }

    @Test func zeroResidualAndSOLAccepted() throws {
        // 잔량 0, SOL 0은 학습 게이트에선 걸러지지만 모델 자체는 무결성 허용
        let obs = try make(predictedResidualAtBedtime: 0, observedSOLMinutes: 0)
        #expect(obs.predictedResidualAtBedtime == 0)
        #expect(obs.observedSOLMinutes == 0)
    }

    // MARK: - 에러 케이스

    @Test func negativeResidualThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(predictedResidualAtBedtime: -1)
        }
    }

    @Test func negativeSOLThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(observedSOLMinutes: -0.1)
        }
    }

    @Test func zeroPriorMeanThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(priorMean: 0)
        }
    }

    @Test func negativePriorMeanThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(priorMean: -2)
        }
    }

    @Test func zeroPosteriorMeanThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(posteriorMean: 0)
        }
    }

    @Test func zeroPriorVarianceThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(priorVariance: 0)
        }
    }

    @Test func zeroPosteriorVarianceThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(posteriorVariance: 0)
        }
    }

    @Test func zeroMultiplierThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(conditionMultiplier: 0)
        }
    }

    @Test func negativeMultiplierThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(conditionMultiplier: -0.5)
        }
    }

    @Test func nanValueThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(priorMean: .nan)
        }
    }

    @Test func infiniteValueThrows() {
        #expect(throws: HalfLifeObservation.ValidationError.self) {
            _ = try make(posteriorVariance: .infinity)
        }
    }
}
