//
//  InsightRepository.swift
//  captest1
//
//  인사이트 도메인 포트(서버 domain/insight). 밤별 잔량·비교·문장은 서버가 계산한다.
//

import Foundation

nonisolated protocol InsightRepository: Sendable {
    /// from~to(양 끝 포함, 아침 날짜 "yyyy-MM-dd") 카페인·수면 리포트. 기간은 31일 이하, to ≤ 오늘.
    func caffeineSleepReport(from: String, to: String, timeZone: TimeZone) async throws -> CaffeineSleepReportResponse
}
