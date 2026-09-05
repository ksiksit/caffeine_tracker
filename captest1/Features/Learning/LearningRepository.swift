//
//  LearningRepository.swift
//  captest1
//
//  학습 도메인 포트(서버 domain/learning). 베이지안 갱신·통계는 서버가 계산한다.
//

import Foundation

nonisolated protocol LearningRepository: Sendable {
    /// 학습 1회 실행(멱등). 갱신된 관측 수와 건너뛴 이유를 돌려준다.
    func run(timeZone: TimeZone) async throws -> LearningRunResponse
    func dashboard() async throws -> LearningDashboardResponse
}
