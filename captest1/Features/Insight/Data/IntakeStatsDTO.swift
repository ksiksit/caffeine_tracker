//
//  IntakeStatsDTO.swift
//  captest1
//
//  기간별 섭취 통계(GET /api/insight/intake-stats) 응답. 총량·평균·초과 여부·요약 문장은 모두 서버가 계산한다.
//  계약: 서버 docs/api/api.md 인사이트 절, openapi.yaml IntakeStatsResponse.
//

import Foundation

nonisolated struct IntakeStatsResponse: Decodable, Sendable {
    let from: String            // 서버 LocalDate(섭취일) "2026-06-01"
    let to: String
    /// 기간 일수(= days 길이)
    let dayCount: Int
    /// 기록이 있는 날 수(끝나지 않은 날 포함)
    let recordedDayCount: Int
    /// 기록 있는 날(섭취일 기준 오늘·이후 제외)의 하루 평균 mg. 그런 날이 없으면 nil
    let averageDailyMg: Double?
    let maxDailyMg: Double?
    /// 하루 400mg 초과 일수(섭취일 기준 오늘·이후 제외)
    let overLimitDayCount: Int
    /// 마지막 섭취 로컬 시각 평균, 벽시계 분 0~1439(예: 1000 = 16:40)
    let averageLastIntakeMinuteOfDay: Int?
    let summarySentence: String
    /// 섭취일 오름차순. 기록이 없는 날도 0으로 들어 있다.
    let days: [IntakeStatsDayDTO]
}

nonisolated struct IntakeStatsDayDTO: Decodable, Sendable {
    /// 섭취일(로컬 05:00 ~ 다음 날 05:00)
    let date: String
    let totalMg: Double
    let recordCount: Int
    let firstIntakeAt: Date?
    let lastIntakeAt: Date?
    /// totalMg > 400 (서버 판정)
    let overLimit: Bool
}
