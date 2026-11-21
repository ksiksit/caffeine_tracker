//
//  IntakeStatsRepository.swift
//  captest1
//
//  기간별 섭취 통계 포트(서버 domain/insight). 섭취일별 총량·기록 수·요약 문장은 서버가 계산한다.
//

import Foundation

nonisolated protocol IntakeStatsRepository: Sendable {
    /// from~to(양 끝 포함, 섭취일 "yyyy-MM-dd") 섭취 통계. 기간은 31일 이하, to ≤ 오늘.
    func intakeStats(from: String, to: String, timeZone: TimeZone) async throws -> IntakeStatsResponse
}
