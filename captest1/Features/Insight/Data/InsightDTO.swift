//
//  InsightDTO.swift
//  captest1
//
//  카페인·수면 상관 리포트(GET /api/insight/caffeine-sleep) 응답. 잔량·비교·문장은 모두 서버가 계산한다.
//  계약: 서버 docs/api/api.md 인사이트 절, openapi.yaml CaffeineSleepReportResponse.
//

import Foundation

nonisolated struct CaffeineSleepReportResponse: Decodable, Sendable {
    let from: String            // 서버 LocalDate(아침 날짜) "2026-06-01"
    let to: String
    let nightCount: Int
    /// 리포트 최소 밤 수 충족. false여도 모든 필드와 nights가 채워진다.
    let sufficient: Bool
    /// 비교 A 경계(50.0). 앱은 이 값으로 잔량 강조 여부를 정한다 — 상수를 따로 두지 않는다.
    let residualThresholdMg: Double
    /// 잔량 계산에 쓴 유효 반감기(요청 시점). 학습 탭 관측 잔량과 같은 밤이라도 값이 다를 수 있다.
    let halfLifeHoursUsed: Double
    let residualComparison: InsightComparisonDTO
    let cutoffComparison: InsightComparisonDTO
    let headlines: [String]
    /// 밤 날짜 오름차순. 수면 데이터가 없거나 bedtimeStart가 없는 밤은 빠져 있다.
    let nights: [InsightNightDTO]
}

nonisolated struct InsightComparisonDTO: Decodable, Sendable {
    let high: InsightGroupDTO
    let low: InsightGroupDTO
    let sufficient: Bool
    let moreNightsNeeded: Int?
    let solDiffMinutes: Double?
    let efficiencyDiff: Double?
    let sentence: String
}

nonisolated struct InsightGroupDTO: Decodable, Sendable {
    let nightCount: Int
    let solNightCount: Int
    let avgSolMinutes: Double?
    let avgSleepEfficiency: Double?
    let avgTotalSleepMinutes: Double?
    let avgDeepSleepRatio: Double?
}

nonisolated struct InsightNightDTO: Decodable, Sendable {
    /// 밤이 끝나는 아침의 로컬 날짜(수면 요약 date와 같다)
    let date: String
    /// bedtimeStart
    let bedtime: Date
    /// 취침 잔량 mg(반올림 없음). 취침 전 24시간 기록이 없으면 0
    let residualAtBedtimeMg: Double
    /// 짝지은 섭취일(D−1 05:00 ~ D 05:00)의 취침 전 섭취 총량 mg. 없으면 0
    let dayTotalMg: Double
    let lastIntakeAt: Date?
    let cutoffKept: Bool?
    /// 같은 date 수면 요약의 SOL ÷ 60. Watch가 없으면 nil
    let solMinutes: Double?
    /// 0~1
    let sleepEfficiency: Double
    let totalSleepMinutes: Double
    let deepSleepRatio: Double?
}
