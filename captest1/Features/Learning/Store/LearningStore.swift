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
    /// 어젯밤이 학습됐는지·건너뛰었는지(관측이 있을 때 Hero 아래 한 줄용). 판단할 근거가 없으면 nil.
    private(set) var lastNight: LastNightLearning?
    /// 대시보드를 받지 못했을 때의 메시지. 빈 상태("아직 학습된 데이터가 없어요")와 구분해 보여준다.
    private(set) var errorMessage: String?
    /// refresh를 한 번이라도 끝냈는가. 첫 로드 전에 빈 상태 카드가 잠깐 보이지 않게 한다.
    private(set) var hasLoaded = false
    /// 학습으로 서버 설정이 바뀔 때마다 1씩 오른다. 설정 미러가 관찰해 다시 받는다.
    private(set) var learnedRevision = 0

    private let repository: any LearningRepository
    private let now: () -> Date

    init(repository: any LearningRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    /// 학습 1회 실행(멱등) 후 대시보드를 갱신한다.
    /// 실패해도 이전 대시보드는 지우지 않는다(마지막으로 받은 값을 계속 보여준다).
    func refresh() async {
        // 수면 업로드 뒤 자동 실행과 탭 진입이 겹치면 같은 밤을 동시에 학습하게 된다.
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        // 학습 실행은 됐는데 대시보드만 실패한 경우에도 아래 재시도에서 실행 결과를 쓴다.
        var run: LearningRunResponse?
        do {
            let result = try await repository.run(timeZone: .current)
            run = result
            skipMessage = result.updatedCount == 0 ? result.skipMessage : nil
            if result.updatedCount > 0 { learnedRevision += 1 }
            let loaded = try await repository.dashboard()
            apply(loaded, run: result)
        } catch is CancellationError {
            return
        } catch APIError.network {
            // 서버에 닿지 않으면 대시보드 재시도도 같은 타임아웃을 한 번 더 기다릴 뿐이다.
            errorMessage = Self.loadFailedMessage
        } catch {
            // 학습 실행만 실패했으면 대시보드만이라도 시도
            do {
                let loaded = try await repository.dashboard()
                apply(loaded, run: run)
            } catch {
                errorMessage = Self.loadFailedMessage
            }
        }
        hasLoaded = true
    }

    /// 받은 대시보드를 반영하고, 어젯밤 학습 여부를 다시 정한다. run이 nil이면 학습 실행이 실패한 것이다.
    private func apply(_ loaded: LearningDashboardResponse, run: LearningRunResponse?) {
        dashboard = loaded
        errorMessage = nil
        lastNight = LastNightLearning.resolve(
            latestObservationDate: loaded.observations.map(\.date).max(),
            today: ServerDateCoding.localDate.string(from: now()),
            updatedCount: run?.updatedCount,
            skipMessage: run?.skipMessage
        )
    }

    /// 로그아웃 시 이전 계정의 값을 지운다.
    func reset() {
        dashboard = nil
        isLoading = false
        skipMessage = nil
        lastNight = nil
        errorMessage = nil
        hasLoaded = false
    }

    private static let loadFailedMessage = "학습 데이터를 불러오지 못했어요. 연결을 확인해주세요."
}
