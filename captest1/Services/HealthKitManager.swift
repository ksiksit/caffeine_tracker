//
//  HealthKitManager.swift
//  captest1
//

import Foundation
import HealthKit

enum HealthKitAccessState: Equatable {
    case unavailable
    case needsRequest
    case requestCompleted
}

@MainActor
@Observable
final class HealthKitManager {
    var isAvailable: Bool = false
    var accessState: HealthKitAccessState = .needsRequest
    var lastNightSummary: SleepSummary?
    var recentSummaries: [SleepSummary] = []
    var isLoading: Bool = false
    var errorMessage: String?
    private(set) var hasLoadedData: Bool = false

    var canAttemptDataLoad: Bool {
        accessState == .requestCompleted
    }

    private let healthStore: HKHealthStore
    private let fetchService: SleepFetchService
    private let settings: SettingsManager
    private var api: APIClient?

    /// 서버 업로드/요약을 위해 APIClient를 주입(앱 부팅 시).
    func attach(api: APIClient) {
        self.api = api
    }

    init(settings: SettingsManager) {
        let store = HKHealthStore()
        healthStore = store
        fetchService = SleepFetchService(healthStore: store)
        self.settings = settings
        isAvailable = HKHealthStore.isHealthDataAvailable()
        accessState = Self.accessState(
            isAvailable: isAvailable,
            requestStatus: nil,
            hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
        )
    }

    nonisolated static func accessState(
        isAvailable: Bool,
        requestStatus: HKAuthorizationRequestStatus?,
        hasRequestedBefore: Bool
    ) -> HealthKitAccessState {
        guard isAvailable else { return .unavailable }
        guard let requestStatus else {
            return hasRequestedBefore ? .requestCompleted : .needsRequest
        }

        switch requestStatus {
        case .shouldRequest:
            return .needsRequest
        case .unnecessary:
            return .requestCompleted
        case .unknown:
            return hasRequestedBefore ? .requestCompleted : .needsRequest
        @unknown default:
            return hasRequestedBefore ? .requestCompleted : .needsRequest
        }
    }

    @discardableResult
    func refreshAccessState() async -> HealthKitAccessState {
        guard isAvailable else {
            accessState = .unavailable
            return accessState
        }

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            accessState = Self.accessState(
                isAvailable: isAvailable,
                requestStatus: nil,
                hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
            )
            return accessState
        }

        do {
            let requestStatus = try await requestStatus(for: sleepType)
            accessState = Self.accessState(
                isAvailable: isAvailable,
                requestStatus: requestStatus,
                hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
            )
        } catch {
            accessState = Self.accessState(
                isAvailable: isAvailable,
                requestStatus: nil,
                hasRequestedBefore: settings.hasRequestedHealthKitAuthorization
            )
        }

        return accessState
    }

    func requestAuthorization() async {
        guard isAvailable else {
            accessState = .unavailable
            return
        }

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            settings.hasRequestedHealthKitAuthorization = true
            await refreshAccessState()
        } catch {
            errorMessage = "HealthKit 권한 요청에 실패했습니다: \(error.localizedDescription)"
            await refreshAccessState()
        }
    }

    func loadDataIfNeeded() async {
        guard !hasLoadedData else { return }
        await loadData()
    }

    func loadData() async {
        let state = await refreshAccessState()
        guard state == .requestCompleted else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let today = Date()
            // 원시 샘플을 서버로 업로드하고, 병합·요약은 서버가 계산한 결과를 표시한다.
            lastNightSummary = try await serverSummary(for: today)
            var recents: [SleepSummary] = []
            for offset in 0..<AppConstants.Sleep.recentHistoryDays {
                guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { continue }
                if let summary = try await serverSummary(for: date) {
                    recents.append(summary)
                }
            }
            recentSummaries = recents
            hasLoadedData = true
        } catch {
            errorMessage = "수면 데이터를 불러오는데 실패했습니다: \(error.localizedDescription)"
        }
    }

    /// HealthKit 원시 샘플을 읽어 서버에 업로드하고, 서버가 병합·계산한 요약을 SleepSummary로 매핑.
    private func serverSummary(for date: Date) async throws -> SleepSummary? {
        guard let api else { return nil }
        let raw = try await fetchService.fetchRawSamples(for: date)
        if !raw.isEmpty {
            let items = raw.map {
                UploadSleepSampleItem(clientUuid: $0.clientUuid, start: $0.start, end: $0.end, hkValue: $0.hkValue)
            }
            _ = try await api.uploadSleepSamples(UploadSleepSamplesRequest(samples: items))
        }
        let response = try await api.sleepSummary(date: Self.localDateString(date))
        guard response.hasData else { return nil }
        let records = response.records.map {
            SleepRecord(startDate: $0.start, endDate: $0.end, stage: SleepStage(from: $0.hkValue))
        }
        return SleepSummary(date: date, records: records, bedtimeStart: response.bedtimeStart)
    }

    private static func localDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func requestStatus(
        for sleepType: HKObjectType
    ) async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: [],
                read: [sleepType]
            ) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}
