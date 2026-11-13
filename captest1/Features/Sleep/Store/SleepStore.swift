//
//  SleepStore.swift
//  captest1
//
//  수면 탭의 서버 상태. HealthKit 원시 샘플을 읽어 서버에 올리고, 서버가 병합·계산한 요약을 표시 모델로 보관한다.
//  권한은 Core/HealthKit/HealthKitManager가 담당하며, 뷰가 권한 확인 후 loadData를 호출한다.
//

import Foundation

@MainActor
@Observable
final class SleepStore {
    private(set) var lastNightSummary: SleepSummary?
    private(set) var recentSummaries: [SleepSummary] = []
    private(set) var isLoading = false
    private(set) var hasLoadedData = false
    /// 로드에 성공할 때마다 1씩 오른다. 업로드 뒤 학습처럼 "새 수면이 올라가면 다시 해야 하는" 쪽이 관찰한다.
    private(set) var loadRevision = 0
    /// 로드를 시도할 때마다(성공·실패 모두) 1씩 오른다. 새로고침에 맞춰 함께 다시 받아야 하는 쪽(밤별 카페인)이 관찰한다.
    private(set) var loadAttemptRevision = 0
    var errorMessage: String?
    private var lastLoadedAt: Date?

    /// 이 시간이 지나면 포그라운드 복귀·탭 진입에서 다시 읽는다. 앱을 띄워 둔 채 잔 지난밤을 올리기 위해서다.
    private static let maxLoadAge: TimeInterval = 3600

    private let samples: any SleepSampleSource
    private let repository: any SleepRepository

    init(samples: any SleepSampleSource, repository: any SleepRepository) {
        self.samples = samples
        self.repository = repository
    }

    func loadDataIfNeeded(now: Date = Date()) async {
        if let lastLoadedAt, now.timeIntervalSince(lastLoadedAt) < Self.maxLoadAge,
           Calendar.current.isDate(lastLoadedAt, inSameDayAs: now) {
            return
        }
        await loadData()
    }

    /// 로그아웃 시 이전 계정의 값을 지운다. 새 계정의 샘플이 다시 올라가도록 로드 기록도 지운다.
    func reset() {
        lastNightSummary = nil
        recentSummaries = []
        isLoading = false
        hasLoadedData = false
        lastLoadedAt = nil
        errorMessage = nil
    }

    /// 오늘부터 최근 N일의 요약을 받아온다. 날짜별 업로드+조회는 병렬(업로드는 clientUuid로 멱등).
    func loadData() async {
        // 같은 샘플을 동시에 올리면 서버 유니크 키가 충돌한다 — 진행 중이면 그 결과를 쓴다.
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let today = Date()
        let calendar = Calendar.current
        let targets: [(offset: Int, date: Date)] = (0..<AppConstants.Sleep.recentHistoryDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { (offset, $0) }
        }

        do {
            let results = try await withThrowingTaskGroup(of: (Int, SleepSummary?).self) { group in
                for target in targets {
                    group.addTask { (target.offset, try await self.summary(for: target.date)) }
                }
                var collected: [(Int, SleepSummary?)] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected.sorted { $0.0 < $1.0 }
            }
            lastNightSummary = results.first?.1
            recentSummaries = results.compactMap(\.1)
            hasLoadedData = true
            lastLoadedAt = Date()
            loadRevision += 1
        } catch is CancellationError {
            // 화면 전환으로 취소된 요청은 실패가 아니다
            return
        } catch {
            errorMessage = Self.userMessage(for: error)
        }
        loadAttemptRevision += 1
    }

    /// 서버 오류는 공용 사용자 문구로 바꾼다 — APIError의 localizedDescription은 "captest1.APIError 오류 11." 같은 내부 이름이다.
    /// HealthKit 오류는 시스템이 사용자용 설명을 주므로 그대로 붙인다.
    static func userMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return "\(apiError.userTitle). \(apiError.userBody)"
        }
        return "수면 데이터를 불러오지 못했어요: \(error.localizedDescription)"
    }

    /// 원시 샘플이 있으면 업로드한 뒤 서버 요약을 받아 표시 모델로 바꾼다. 데이터가 없는 날은 nil.
    private func summary(for date: Date) async throws -> SleepSummary? {
        // 길이 0(end == start) 샘플은 서버가 배치 전체를 400으로 거절하므로 업로드 전에 뺀다. 병합 결과에는 영향 없음.
        let raw = try await samples.fetchRawSamples(for: date).filter { $0.end > $0.start }
        if !raw.isEmpty {
            let items = raw.map {
                UploadSleepSampleItem(clientUuid: $0.clientUuid, start: $0.start, end: $0.end, hkValue: $0.hkValue)
            }
            _ = try await repository.uploadSamples(UploadSleepSamplesRequest(samples: items))
        }
        let response = try await repository.summary(
            date: ServerDateCoding.localDate.string(from: date),
            timeZone: .current
        )
        guard response.hasData else { return nil }
        return SleepSummary(date: date, response: response)
    }
}
