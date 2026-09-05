//
//  ServerLearningDTO.swift
//  captest1
//
//  학습 실행/대시보드 DTO. 베이지안 학습·통계는 서버가 계산한다.
//

import Foundation

nonisolated struct LearningRunResponse: Decodable, Sendable {
    let updatedCount: Int
    let skipReason: String?
    let skipMessage: String?
}

nonisolated struct LearningDashboardResponse: Decodable, Sendable {
    let count: Int
    let latest: LatestEstimate?
    let observations: [ObservationItem]
    let calibration: Calibration
    let residualHistogram: [HistogramBinItem]
    let solHistogram: [HistogramBinItem]
}

nonisolated struct LatestEstimate: Decodable, Sendable {
    let posteriorMean: Double
    let posteriorVariance: Double
    let ciLower: Double
    let ciUpper: Double
    let confidence: Double
}

nonisolated struct ObservationItem: Decodable, Identifiable, Sendable {
    let date: String   // 서버 LocalDate "2026-06-01"
    let predictedResidualAtBedtime: Double
    let observedSolMinutes: Double
    let priorMean: Double
    let posteriorMean: Double
    let posteriorVariance: Double
    let conditionMultiplier: Double

    var id: String { date }

    /// 차트 x축용. 서버 LocalDate를 로컬 날짜로.
    var parsedDate: Date {
        ServerDateCoding.localDate.date(from: date) ?? Date()
    }
}

nonisolated struct Calibration: Decodable, Sendable {
    let points: [PointItem]
    let rSquared: Double?
    let rmse: Double
    let domainLower: Double
    let domainUpper: Double
}

nonisolated struct PointItem: Decodable, Sendable {
    let predicted: Double
    let observed: Double
}

nonisolated struct HistogramBinItem: Decodable, Identifiable, Sendable {
    let lower: Double
    let upper: Double
    let count: Int

    var id: Double { lower }
    var label: String { String(format: "%.0f-%.0f", lower, upper) }
}
