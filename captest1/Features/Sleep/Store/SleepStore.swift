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
    var errorMessage: String?

    private let samples: any SleepSampleSource
    private let repository: any SleepRepository

    init(samples: any SleepSampleSource, repository: any SleepRepository) {
        self.samples = samples
        self.repository = repository
    }

    func loadDataIfNeeded() async {
        guard !hasLoadedData else { return }
        await loadData()
    }

    /// 오늘부터 최근 N일의 요약을 받아온다. 날짜별 업로드+조회는 병렬(업로드는 clientUuid로 멱등).
    func loadData() async {
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
        } catch {
            errorMessage = "수면 데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }
    }

    /// 원시 샘플이 있으면 업로드한 뒤 서버 요약을 받아 표시 모델로 바꾼다. 데이터가 없는 날은 nil.
    private func summary(for date: Date) async throws -> SleepSummary? {
        let raw = try await samples.fetchRawSamples(for: date)
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
