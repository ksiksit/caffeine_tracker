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

    // MARK: - UI 상태
    var showingAddSheet = false
    var halfLife: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours

    // MARK: - 파생 데이터
    var chartDoses: [CaffeineKineticsCalculator.Dose] {
        toDoses(todayRecords)
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
        guard !doses.isEmpty else {
            chartDataPoints = []
            return
        }
        let start = Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(Double(AppConstants.Pharmacokinetics.chartStartHour) * 3600)
        let end = start.addingTimeInterval(Double(AppConstants.Pharmacokinetics.chartForwardHours) * 3600)
        let points = await Task.detached(priority: .userInitiated) {
            CaffeineKineticsCalculator.generateTimeSeries(
                doses: doses, from: start, to: end, halfLifeHours: hl
            )
        }.value
        currentTime = Date()
        chartDataPoints = points
    }
}
