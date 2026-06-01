//
//  LearningStore.swift
//  captest1
//
//  학습 대시보드의 서버 상태. 학습 실행(run)과 대시보드 조회를 서버에 위임한다.
//  (← 기존 로컬 BayesianHalfLifeLearner + SwiftData @Query 대체)
//

import Foundation

@MainActor
@Observable
final class LearningStore {
    private(set) var dashboard: LearningDashboardResponse?
    private(set) var isLoading = false
    /// 학습이 건너뛰어진 경우 사용자에게 보여줄 메시지(빈 상태 카드용).
    private(set) var skipMessage: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    /// 학습 1회 실행(멱등) 후 대시보드를 갱신한다.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let run = try await api.learningRun()
            skipMessage = run.updatedCount == 0 ? run.skipMessage : nil
            dashboard = try await api.learningDashboard()
        } catch is CancellationError {
            // 무시
        } catch {
            // 대시보드만이라도 시도
            dashboard = try? await api.learningDashboard()
        }
    }
}
