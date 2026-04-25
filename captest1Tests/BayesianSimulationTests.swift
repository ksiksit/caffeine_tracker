//
//  BayesianSimulationTests.swift
//  captest1Tests
//
//  30일 합성 데이터로 학습 수렴성 + β 민감도 분석.
//  발표용 plot 생성에 활용.
//

import Foundation
import SwiftData
import Testing
@testable import captest1

@MainActor
struct BayesianSimulationTests {

    private struct SimulationResult {
        let beta: Double
        let finalMean: Double
        let finalVariance: Double
        let bias: Double            // |finalMean - trueHalfLife|
        let trajectory: [Double]    // 일별 사후 평균 (발표 plot용)
    }

    /// 반복 가능한 정규분포 노이즈 (Box-Muller).
    private struct SeededRNG {
        var state: UInt64
        mutating func nextUniform() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        mutating func nextGaussian(mean: Double = 0, std: Double = 1) -> Double {
            let u1 = max(nextUniform(), 1e-12)
            let u2 = nextUniform()
            return mean + std * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
        }
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([CaffeineRecord.self, HalfLifeObservation.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// 1명의 가상 사용자에 대해 days일간 학습을 수행.
    /// - trueHalfLife: 실제 base 반감기 (h)
    /// - beta: likelihood β
    /// - seed: 난수 시드
    private func runSimulation(trueHalfLife: Double, beta: Double,
                               days: Int, seed: UInt64) throws -> SimulationResult {
        let ctx = try makeContext()
        let s = SettingsManager()
        s.halfLife = 5.0  // 슬라이더는 모집단 평균
        s.learnedHalfLifeVariance = SettingsManager.populationPriorVariance
        s.isLearningEnabled = true
        s.conditionRawValue = 0
        s.lastLearnedDate = nil

        var params = BayesianHalfLifeLearner.LikelihoodParams()
        params.beta = beta
        let learner = BayesianHalfLifeLearner(
            settings: s, context: ctx, params: params
        )

        var rng = SeededRNG(state: seed)
        var trajectory: [Double] = []

        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.startOfDay(for: Date()).addingTimeInterval(-Double(days) * 86400)

        for d in 0..<days {
            // 그 날의 기준일
            let dayStart = startDay.addingTimeInterval(Double(d) * 86400)
            // 카페인 1~3잔, 각 14~18시 사이 무작위, 100~250mg
            let numDoses = Int(rng.nextUniform() * 3) + 1
            var doses: [CaffeineRecord] = []
            for _ in 0..<numDoses {
                let hour = 14 + rng.nextUniform() * 4  // 14~18시
                let amount = Int(100 + rng.nextUniform() * 150)
                let timestamp = dayStart.addingTimeInterval(hour * 3600)
                doses.append(CaffeineRecord(amount: amount, drinkName: "sim",
                                            timestamp: timestamp))
            }
            // 취침: 23시
            let bedtime = dayStart.addingTimeInterval(23 * 3600)
            // 실제 잔량 (true half-life 사용)
            let cTrue = CaffeineKineticsCalculator.totalRemaining(
                at: bedtime,
                doses: doses.map {
                    CaffeineKineticsCalculator.Dose(timestamp: $0.timestamp,
                                                    amountMg: Double($0.amount))
                },
                halfLifeHours: trueHalfLife
            )
            // SOL = α + β·cTrue + N(0, σ_obs)
            let solMinutes = max(0, params.alpha + params.beta * cTrue
                                 + rng.nextGaussian(std: params.sigmaObs))
            // 다음날 새벽 6시까지 7시간 수면
            let asleepStart = bedtime.addingTimeInterval(solMinutes * 60)
            let asleepEnd = bedtime.addingTimeInterval(8 * 3600)
            let sum = SleepSummary(date: asleepEnd, records: [
                SleepRecord(startDate: bedtime, endDate: asleepStart, stage: .inBed),
                SleepRecord(startDate: asleepStart, endDate: asleepEnd, stage: .asleepCore)
            ])

            _ = learner.updateIfNewObservation(
                yesterdaySummary: sum,
                allCaffeineRecords: doses
            )
            trajectory.append(s.learnedHalfLifeMean)
        }

        return SimulationResult(
            beta: beta,
            finalMean: s.learnedHalfLifeMean,
            finalVariance: s.learnedHalfLifeVariance,
            bias: abs(s.learnedHalfLifeMean - trueHalfLife),
            trajectory: trajectory
        )
    }

    // MARK: - 수렴 테스트

    @Test func convergesToTrueHalfLife_FastMetabolizer() throws {
        // 빠른 대사자 (3.5h) — prior 5.0에서 1.5h 떨어짐. trust region 0.5h/day로 60일 필요.
        let result = try runSimulation(trueHalfLife: 3.5, beta: 0.10, days: 60, seed: 42)
        #expect(result.bias < 1.0,
                "fast metabolizer 시뮬: bias=\(result.bias), final=\(result.finalMean)")
    }

    @Test func convergesToTrueHalfLife_SlowMetabolizer() throws {
        // 느린 대사자 (6.5h) — prior에서 1.5h 떨어짐, 60일.
        let result = try runSimulation(trueHalfLife: 6.5, beta: 0.10, days: 60, seed: 7)
        #expect(result.bias < 1.0,
                "slow metabolizer 시뮬: bias=\(result.bias), final=\(result.finalMean)")
    }

    @Test func varianceShrinksWithObservations() throws {
        let result = try runSimulation(trueHalfLife: 5.5, beta: 0.10, days: 30, seed: 100)
        // 30일 후 분산은 prior 분산(2.25)보다 줄어야 함
        #expect(result.finalVariance < SettingsManager.populationPriorVariance)
    }

    // MARK: - β 민감도 분석

    @Test func betaSensitivityAnalysis() throws {
        let trueHL = 6.0
        let betas: [Double] = [0.05, 0.10, 0.15, 0.20]
        var results: [SimulationResult] = []
        for (i, beta) in betas.enumerated() {
            let result = try runSimulation(
                trueHalfLife: trueHL, beta: beta,
                days: 30, seed: UInt64(1000 + i)
            )
            results.append(result)
        }
        // 발표용 plot 데이터를 콘솔에 출력
        print("=== β Sensitivity (true half-life = \(trueHL)h, 30 days) ===")
        for r in results {
            print(String(format: "β=%.2f → final=%.3fh, bias=%.3fh, var=%.4f",
                         r.beta, r.finalMean, r.bias, r.finalVariance))
        }
        // 모든 β에서 bias가 1.5h 이내이면 robust 판정
        for r in results {
            #expect(r.bias < 1.5,
                    "β=\(r.beta)에서 bias=\(r.bias)로 너무 큼")
        }
    }
}
