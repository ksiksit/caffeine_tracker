//
//  CaffeineKineticsCalculatorTests.swift
//  captest1Tests
//

import Foundation
import Testing
@testable import captest1

struct CaffeineKineticsCalculatorTests {

    @Test func remainingAmount_afterOneHalfLife_is50Percent() {
        let result = CaffeineKineticsCalculator.remainingAmount(
            dose: 100, hoursSinceDose: 5.0, halfLifeHours: 5.0
        )
        #expect(abs(result - 50.0) < 0.01)
    }

    @Test func remainingAmount_afterTwoHalfLives_is25Percent() {
        let result = CaffeineKineticsCalculator.remainingAmount(
            dose: 200, hoursSinceDose: 10.0, halfLifeHours: 5.0
        )
        #expect(abs(result - 50.0) < 0.01)
    }

    @Test func remainingAmount_atTimeZero_equalsFullDose() {
        let result = CaffeineKineticsCalculator.remainingAmount(
            dose: 150, hoursSinceDose: 0
        )
        #expect(abs(result - 150.0) < 0.01)
    }

    @Test func remainingAmount_negativeTime_returnsZero() {
        let result = CaffeineKineticsCalculator.remainingAmount(
            dose: 100, hoursSinceDose: -1
        )
        #expect(result == 0)
    }

    @Test func remainingAmount_zeroDose_returnsZero() {
        let result = CaffeineKineticsCalculator.remainingAmount(
            dose: 0, hoursSinceDose: 1
        )
        #expect(result == 0)
    }

    @Test func remainingAmount_afterManyHours_nearZero() {
        let result = CaffeineKineticsCalculator.remainingAmount(
            dose: 100, hoursSinceDose: 50, halfLifeHours: 5.0
        )
        #expect(result < 0.1)
    }

    @Test func totalRemaining_superpositionAddsDoses() {
        let now = Date()
        let dose1 = CaffeineKineticsCalculator.Dose(
            timestamp: now.addingTimeInterval(-3600), amountMg: 100
        )
        let dose2 = CaffeineKineticsCalculator.Dose(
            timestamp: now.addingTimeInterval(-1800), amountMg: 100
        )
        let combined = CaffeineKineticsCalculator.totalRemaining(
            at: now, doses: [dose1, dose2]
        )
        let single = CaffeineKineticsCalculator.totalRemaining(
            at: now, doses: [dose1]
        )
        #expect(combined > single)
    }

    @Test func totalRemaining_futureDoseNotCounted() {
        let now = Date()
        let futureDose = CaffeineKineticsCalculator.Dose(
            timestamp: now.addingTimeInterval(3600), amountMg: 100
        )
        let result = CaffeineKineticsCalculator.totalRemaining(
            at: now, doses: [futureDose]
        )
        #expect(result == 0)
    }

    @Test func generateTimeSeries_correctPointCount() {
        let now = Date()
        let dose = CaffeineKineticsCalculator.Dose(timestamp: now.addingTimeInterval(-7200), amountMg: 150)
        let start = now
        let end = now.addingTimeInterval(3600) // 1 hour
        let points = CaffeineKineticsCalculator.generateTimeSeries(
            doses: [dose], from: start, to: end, intervalMinutes: 15
        )
        // 0, 15, 30, 45, 60 min = 5 regular points (no dose within range → no extra points)
        #expect(points.count == 5)
    }

    @Test func generateTimeSeries_emptyDoses_allZero() {
        let now = Date()
        let points = CaffeineKineticsCalculator.generateTimeSeries(
            doses: [], from: now, to: now.addingTimeInterval(3600), intervalMinutes: 15
        )
        let allZero = points.allSatisfy { $0.concentrationMg == 0 }
        #expect(allZero)
    }

    @Test func generateTimeSeries_isSortedByTime() {
        let now = Date()
        let dose = CaffeineKineticsCalculator.Dose(timestamp: now.addingTimeInterval(900), amountMg: 100)
        let points = CaffeineKineticsCalculator.generateTimeSeries(
            doses: [dose], from: now, to: now.addingTimeInterval(3600), intervalMinutes: 15
        )
        for i in 1..<points.count {
            #expect(points[i].time >= points[i - 1].time)
        }
    }

    @Test func remainingAmount_customHalfLife() {
        let short = CaffeineKineticsCalculator.remainingAmount(
            dose: 100, hoursSinceDose: 3, halfLifeHours: 3.0
        )
        let long = CaffeineKineticsCalculator.remainingAmount(
            dose: 100, hoursSinceDose: 3, halfLifeHours: 7.0
        )
        #expect(abs(short - 50.0) < 0.01)
        #expect(long > short)
    }

    // MARK: - nearestConcentration

    @Test func nearestConcentration_exactMatch() {
        let now = Date()
        let points = [
            CaffeineKineticsCalculator.DataPoint(index: 0, time: now, concentrationMg: 100),
            CaffeineKineticsCalculator.DataPoint(index: 1, time: now.addingTimeInterval(900), concentrationMg: 80),
        ]
        let result = CaffeineKineticsCalculator.nearestConcentration(at: now, in: points)
        #expect(abs(result - 100.0) < 0.01)
    }

    @Test func nearestConcentration_betweenPoints() {
        let now = Date()
        let points = [
            CaffeineKineticsCalculator.DataPoint(index: 0, time: now, concentrationMg: 100),
            CaffeineKineticsCalculator.DataPoint(index: 1, time: now.addingTimeInterval(900), concentrationMg: 80),
        ]
        // 600초 후 → 첫 번째 포인트(0초)보다 두 번째 포인트(900초)에 더 가까움
        let result = CaffeineKineticsCalculator.nearestConcentration(
            at: now.addingTimeInterval(600), in: points
        )
        #expect(abs(result - 80.0) < 0.01)
    }

    @Test func nearestConcentration_emptyArray() {
        let result = CaffeineKineticsCalculator.nearestConcentration(at: Date(), in: [])
        #expect(result == 0)
    }
}
