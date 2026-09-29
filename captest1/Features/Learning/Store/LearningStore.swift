//
//  LearningStore.swift
//  captest1
//
//  학습 대시보드의 서버 상태. 학습 실행(run)과 대시보드 조회를 서버에 위임한다.
//

import Foundation

@MainActor
@Observable
final class LearningStore {
    private(set) var dashboard: LearningDashboardResponse?
    private(set) var isLoading = false
    /// 학습이 건너뛰어진 경우 사용자에게 보여줄 메시지(빈 상태 카드용).
    private(set) var skipMessage: String?
    /// 대시보드를 받지 못했을 때의 메시지. 빈 상태("아직 학습된 데이터가 없어요")와 구분해 보여준다.
    private(set) var errorMessage: String?
    /// refresh를 한 번이라도 끝냈는가. 첫 로드 전에 빈 상태 카드가 잠깐 보이지 않게 한다.
    private(set) var hasLoaded = false

    private let repository: any LearningRepository

    init(repository: any LearningRepository) {
        self.repository = repository
    }

    /// 학습 1회 실행(멱등) 후 대시보드를 갱신한다.
    /// 실패해도 이전 대시보드는 지우지 않는다(마지막으로 받은 값을 계속 보여준다).
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let run = try await repository.run(timeZone: .current)
            skipMessage = run.updatedCount == 0 ? run.skipMessage : nil
            dashboard = try await repository.dashboard()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch APIError.network {
            // 서버에 닿지 않으면 대시보드 재시도도 같은 타임아웃을 한 번 더 기다릴 뿐이다.
            errorMessage = Self.loadFailedMessage
        } catch {
            // 학습 실행만 실패했으면 대시보드만이라도 시도
            do {
                dashboard = try await repository.dashboard()
                errorMessage = nil
            } catch {
                errorMessage = Self.loadFailedMessage
            }
        }
        hasLoaded = true
    }

    private static let loadFailedMessage = "학습 데이터를 불러오지 못했어요. 연결을 확인해주세요."
}
