//
//  HomeViewModel.swift
//  captest1
//

import Foundation

@MainActor @Observable
final class HomeViewModel {
    // MARK: - 데이터 상태
    private(set) var todayRecords: [CaffeineRecord] = []
    private(set) var todayTotal: Int = 0
    private(set) var chartDataPoints: [CaffeineKineticsCalculator.DataPoint] = []
    private(set) var currentTime = Date()
    private(set) var currentResidual: Double = 0
    private(set) var predictedAtBedtime: Double = 0
    private(set) var cutoffResult: CaffeineCutoffResult = .safeAnytime

    // MARK: - UI 상태
    var showingAddSheet = false
    var halfLife: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours
    var bedtimeHour: Int = 23
    var bedtimeMinute: Int = 0
    var referenceDoseMg: Double = Double(AppConstants.Caffeine.defaultReferenceDoseMg)

    // MARK: - 파생 데이터
    var chartDoses: [CaffeineKineticsCalculator.Dose] {
        toDoses(todayRecords)
    }

    var canDrinkNow: Bool {
        todayRecords.isEmpty || predictedAtBedtime <= AppConstants.Caffeine.bedtimeSafeThresholdMg
    }

    // MARK: - 레코드 업데이트
    func updateRecords(_ allRecords: [CaffeineRecord]) {
        todayRecords = filterTodayRecords(allRecords)
        todayTotal = calculateTotalCaffeine(todayRecords)
    }

    // MARK: - 차트 데이터 생성
    func updateChartData() async {
        let doses = chartDoses
        let hl = halfLife
        let now = Date()
        currentTime = now
        let bedtime = nextBedtime(now: now, hour: bedtimeHour, minute: bedtimeMinute)

        guard !doses.isEmpty else {
            chartDataPoints = []
            currentResidual = 0
            predictedAtBedtime = 0
            cutoffResult = caffeineCutoffTime(
                currentDoses: [],
                bedtime: bedtime,
                referenceDoseMg: referenceDoseMg,
                halfLifeHours: hl
            )
            return
        }

        let start = Calendar.current.startOfDay(for: now)
            .addingTimeInterval(Double(AppConstants.Pharmacokinetics.chartStartHour) * 3600)
        let end = start.addingTimeInterval(Double(AppConstants.Pharmacokinetics.chartForwardHours) * 3600)
        let points = await Task.detached(priority: .userInitiated) {
            CaffeineKineticsCalculator.generateTimeSeries(
                doses: doses, from: start, to: end, halfLifeHours: hl
            )
        }.value
        chartDataPoints = points

        currentResidual = CaffeineKineticsCalculator.totalRemaining(
            at: now, doses: doses, halfLifeHours: hl
        )
        predictedAtBedtime = CaffeineKineticsCalculator.totalRemaining(
            at: bedtime, doses: doses, halfLifeHours: hl
        )
        cutoffResult = caffeineCutoffTime(
            currentDoses: doses,
            bedtime: bedtime,
            referenceDoseMg: referenceDoseMg,
            halfLifeHours: hl
        )
    }

    private func nextBedtime(now: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        guard let todayBedtime = calendar.date(from: components) else { return now }
        if todayBedtime <= now {
            return calendar.date(byAdding: .day, value: 1, to: todayBedtime) ?? todayBedtime
        }
        return todayBedtime
    }
}
